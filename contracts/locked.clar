(define-constant TOKEN_CAP u1000000) ;; Maximum supply limit for any token
(define-constant ADMIN_ADDRESS tx-sender) ;; Admin of the contract

;; Data structure to store token details
(define-data-var token-metadata
    { title: (string-ascii 32), ticker: (string-ascii 10), circulation: uint }
    (tuple (title "") (ticker "") (circulation u0))
)

;; Map to store balances of users for each token
(define-map holdings principal uint)

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_BALANCE_LOW u102)
(define-constant ERR_TOKEN_ALREADY_EXISTS u103)
(define-constant ERR_INVALID_RECIPIENT u104)

;; Mint a new token with a custom supply, name, and symbol
(define-public (create-token (title (string-ascii 32)) (ticker (string-ascii 10)) (amount uint))
    (begin
        ;; Ensure the caller is the contract admin
        (asserts! (is-eq tx-sender ADMIN_ADDRESS) (err ERR_UNAUTHORIZED))
        ;; Ensure the supply is valid and within limits
        (asserts! (and (> amount u0) (<= amount TOKEN_CAP)) (err ERR_INVALID_AMOUNT))
        ;; Ensure the token does not already exist
        (asserts! (is-eq (get circulation (var-get token-metadata)) u0) (err ERR_TOKEN_ALREADY_EXISTS))
        ;; Update token details
        (var-set token-metadata (tuple (title title) (ticker ticker) (circulation amount)))
        ;; Mint tokens to the contract admin
        (map-set holdings tx-sender amount)
        (ok true)
    )
)

;; Transfer tokens from the sender to another principal
(define-public (send-tokens (recipient principal) (amount uint))
    (begin
        ;; Ensure amount is greater than zero
        (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
        
        ;; Ensure recipient is valid (not sending to zero address)
        (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) (err ERR_INVALID_RECIPIENT))
        
        ;; Ensure the sender has enough balance
        (let ((sender-balance (default-to u0 (map-get? holdings tx-sender))))
            (asserts! (>= sender-balance amount) (err ERR_BALANCE_LOW))
            
            ;; Update sender's balance
            (map-set holdings tx-sender (- sender-balance amount))
            
            ;; Update recipient's balance (safely)
            (let ((recipient-balance (default-to u0 (map-get? holdings recipient))))
                (map-set holdings recipient (+ recipient-balance amount))
                (ok true)
            )
        )
    )
)

;; Burn tokens from the sender's balance
(define-public (destroy-tokens (amount uint))
    (begin
        ;; Ensure amount is greater than zero
        (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
        
        ;; Ensure the sender has enough balance
        (let ((sender-balance (default-to u0 (map-get? holdings tx-sender))))
            (asserts! (>= sender-balance amount) (err ERR_BALANCE_LOW))
            
            ;; Update sender's balance
            (map-set holdings tx-sender (- sender-balance amount))
            
            ;; Update total supply
            (let ((current-circulation (get circulation (var-get token-metadata))))
                (var-set token-metadata (merge (var-get token-metadata) 
                                              (tuple (circulation (- current-circulation amount)))))
                (ok true)
            )
        )
    )
)

;; Get the balance of a specific principal
(define-read-only (check-balance (user principal))
    (default-to u0 (map-get? holdings user))
)

;; Get token details (name, symbol, total supply)
(define-read-only (get-token-info)
    (var-get token-metadata)
)