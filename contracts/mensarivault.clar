;; ================================================
;; Mensari STX Yield Vault - Earn USDCx
;; Users stake STX | Earn USDCx as rewards
;; Owner manually adds USDCx rewards
;; ================================================

(define-constant ERR_INVALID_AMOUNT   (err u101))
(define-constant ERR_NOT_OWNER        (err u102))
(define-constant ERR_NO_DEPOSIT       (err u103))
(define-constant ERR_INVALID_LOCK     (err u104))
(define-constant ERR_LOCKED           (err u105))
(define-constant ERR_PAUSED           (err u106))

(define-constant USDCX 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx)
(define-constant REWARD_PRECISION u1000000)

;; Lock Periods (in blocks) - Starting from 60 days
(define-constant LOCK_60DAYS    u8640)
(define-constant LOCK_180DAYS   u25920)
(define-constant LOCK_360DAYS   u51840)
(define-constant LOCK_900DAYS   u129600)
(define-constant LOCK_1800DAYS  u259200)

;; Reward Multipliers
(define-constant MULTIPLIER_60DAYS    u100)
(define-constant MULTIPLIER_180DAYS   u120)
(define-constant MULTIPLIER_360DAYS   u140)
(define-constant MULTIPLIER_900DAYS   u175)
(define-constant MULTIPLIER_1800DAYS  u220)

;; Data
(define-map deposits principal uint)
(define-map deposit-time principal uint)
(define-map lock-period principal uint)
(define-map reward-debt principal uint)
(define-map accrued-rewards principal uint)

(define-data-var total-deposited uint u0)
(define-data-var total-rewards uint u0)
(define-data-var reward-per-token uint u0)
(define-data-var paused bool false)
(define-data-var vault-owner principal tx-sender)

;; ===================== HELPERS =====================
(define-private (assert-not-paused)
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (ok true)))

(define-private (assert-owner)
  (begin
    (asserts! (is-eq tx-sender (var-get vault-owner)) ERR_NOT_OWNER)
    (ok true)))

(define-private (distribute-rewards (amount uint))
  (if (> (var-get total-deposited) u0)
      (begin
        (var-set reward-per-token
          (+ (var-get reward-per-token)
             (/ (* amount REWARD_PRECISION) (var-get total-deposited))))
        true)
      true))

(define-private (settle-rewards (user principal))
  (let
    (
      (balance (default-to u0 (map-get? deposits user)))
      (rpt (var-get reward-per-token))
      (debt (default-to u0 (map-get? reward-debt user)))
      (accrued (default-to u0 (map-get? accrued-rewards user)))
      (gross (/ (* balance rpt) REWARD_PRECISION))
      (pending (if (> gross debt) (- gross debt) u0))
    )
    (map-set accrued-rewards user (+ accrued pending))
    (map-set reward-debt user gross)
    pending))

;; ===================== DEPOSIT =====================
(define-public (deposit (amount uint) (lock-choice uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (or (is-eq lock-choice LOCK_60DAYS)
                  (is-eq lock-choice LOCK_180DAYS)
                  (is-eq lock-choice LOCK_360DAYS)
                  (is-eq lock-choice LOCK_900DAYS)
                  (is-eq lock-choice LOCK_1800DAYS))
              ERR_INVALID_LOCK)

    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    (settle-rewards tx-sender)

    (map-set deposits tx-sender 
      (+ (default-to u0 (map-get? deposits tx-sender)) amount))
    
    (map-set deposit-time tx-sender stacks-block-height)
    (map-set lock-period tx-sender lock-choice)

    (var-set total-deposited (+ (var-get total-deposited) amount))
    (print {event: "deposit", user: tx-sender, amount: amount, lock: lock-choice})
    (ok true)
  )
)

;; ===================== WITHDRAW =====================
(define-public (withdraw)
  (let
    (
      (user-deposit (default-to u0 (map-get? deposits tx-sender)))
      (deposit-block (default-to u0 (map-get? deposit-time tx-sender)))
      (user-lock (default-to u0 (map-get? lock-period tx-sender)))
      (caller tx-sender)
      (user-reward (begin (settle-rewards tx-sender)
                      (default-to u0 (map-get? accrued-rewards tx-sender))))
      (multiplier (get-multiplier user-lock))
      (final-reward (/ (* user-reward multiplier) u100))
    )
    (try! (assert-not-paused))
    (asserts! (> user-deposit u0) ERR_NO_DEPOSIT)
    (asserts! (>= (- stacks-block-height deposit-block) user-lock) ERR_LOCKED)

    ;; Return STX
    (as-contract (try! (stx-transfer? user-deposit tx-sender caller)))

    ;; Send USDCx rewards
    (try! (contract-call? USDCX transfer final-reward (as-contract tx-sender) caller none))

    ;; Reset user
    (map-set deposits tx-sender u0)
    (map-set deposit-time tx-sender u0)
    (map-set lock-period tx-sender u0)
    (map-set reward-debt tx-sender u0)
    (map-set accrued-rewards tx-sender u0)
    (var-set total-deposited (- (var-get total-deposited) user-deposit))

    (print {event: "withdraw", user: tx-sender, principal: user-deposit, rewards: final-reward})
    (ok {
      withdrawn: user-deposit,
      principal: user-deposit,
      rewards: final-reward
    })
  )
)

;; Helper
(define-private (get-multiplier (lock uint))
  (if (is-eq lock LOCK_1800DAYS) MULTIPLIER_1800DAYS
  (if (is-eq lock LOCK_900DAYS)  MULTIPLIER_900DAYS
  (if (is-eq lock LOCK_360DAYS)  MULTIPLIER_360DAYS
  (if (is-eq lock LOCK_180DAYS)  MULTIPLIER_180DAYS
      MULTIPLIER_60DAYS)))))

;; ===================== ADD USDCx REWARDS =====================
(define-public (add-rewards (amount uint))
  (begin
    (try! (assert-owner))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (try! (contract-call? USDCX transfer amount tx-sender (as-contract tx-sender) none))

    (var-set total-rewards (+ (var-get total-rewards) amount))
    (distribute-rewards amount)

    (print {event: "add-rewards", amount: amount})
    (ok true)
  )
)

;; ===================== EMERGENCY FUNCTIONS =====================
(define-public (emergency-drain)
  (begin
    (try! (assert-owner))
    (let ((balance (stx-get-balance (as-contract tx-sender))))
      (as-contract (try! (stx-transfer? balance tx-sender (var-get vault-owner))))
      (print {event: "emergency-drain", amount: balance})
      (ok balance)
    )
  )
)

(define-public (set-owner (new-owner principal))
  (begin
    (try! (assert-owner))
    (var-set vault-owner new-owner)
    (print {event: "set-owner", new-owner: new-owner})
    (ok true)
  )
)

(define-public (pause)
  (begin
    (try! (assert-owner))
    (var-set paused true)
    (print {event: "pause", by: tx-sender})
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (try! (assert-owner))
    (var-set paused false)
    (print {event: "unpause", by: tx-sender})
    (ok true)
  )
)

;; Read-only
(define-read-only (get-user-deposit (user principal))
  (ok (default-to u0 (map-get? deposits user))))

(define-read-only (get-user-lock-period (user principal))
  (ok (default-to u0 (map-get? lock-period user))))

(define-read-only (get-total-deposited)
  (ok (var-get total-deposited)))

(define-read-only (get-user-rewards (user principal))
  (ok (default-to u0 (map-get? accrued-rewards user))))

(define-read-only (get-owner)
  (ok (var-get vault-owner)))

(define-read-only (get-paused)
  (ok (var-get paused)))