(define-constant TOKEN_CAP u1000000) ;; Maximum supply limit for any token
(define-constant ADMIN_ADDRESS tx-sender) ;; Admin of the contract
(define-constant MAX_LOCK_PERIOD u52560) ;; Maximum lock period (approximately 1 year in blocks)

;; Data structure to store token details
(define-data-var token-metadata
    { title: (string-ascii 32), ticker: (string-ascii 10), circulation: uint }
    (tuple (title "") (ticker "") (circulation u0))
)

;; Map to store balances of users for each token
(define-map holdings principal uint)

;; Map to track locked tokens with unlock heights
(define-map token-locks { owner: principal } { amount: uint, unlock-height: uint })

;; Map to store allowances for delegated transfers
(define-map allowances { owner: principal, spender: principal } uint)

;; Error codes
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_BALANCE_LOW u102)
(define-constant ERR_TOKEN_ALREADY_EXISTS u103)
(define-constant ERR_INVALID_RECIPIENT u104)
(define-constant ERR_TOKENS_LOCKED u105)
(define-constant ERR_ALLOWANCE_EXCEEDED u106)
(define-constant ERR_INVALID_LOCK_PERIOD u107)
(define-constant ERR_INVALID_SPENDER u108)

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
        
        ;; Check if sender has locked tokens
        (match (map-get? token-locks { owner: tx-sender })
            lock (asserts! 
                (or 
                    (< (get amount lock) amount)  ;; Sending more than locked amount
                    (>= block-height (get unlock-height lock))  ;; Lock period expired
                ) 
                (err ERR_TOKENS_LOCKED))
            true  ;; No lock record found
        )
        
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

;; FUNCTIONALITY 1: Lock tokens for a specified period
(define-public (lock-tokens (amount uint) (lock-period uint))
    (begin
        ;; Ensure amount is greater than zero
        (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
        
        ;; Validate lock period - must be positive and not excessive
        (asserts! (and (> lock-period u0) (<= lock-period MAX_LOCK_PERIOD)) (err ERR_INVALID_LOCK_PERIOD))
        
        ;; Ensure the sender has enough balance
        (let ((sender-balance (default-to u0 (map-get? holdings tx-sender))))
            (asserts! (>= sender-balance amount) (err ERR_BALANCE_LOW))
            
            ;; Calculate unlock height (safely)
            (let ((current-block block-height)
                  (unlock-at (+ block-height lock-period)))
                
                ;; Ensure unlock height calculation doesn't overflow
                (asserts! (> unlock-at current-block) (err ERR_INVALID_LOCK_PERIOD))
                
                ;; Store lock information
                (map-set token-locks 
                    { owner: tx-sender } 
                    { amount: amount, unlock-height: unlock-at }
                )
                (ok unlock-at)
            )
        )
    )
)

;; FUNCTIONALITY 2: Approve spending allowance for another principal
(define-public (approve (spender principal) (amount uint))
    (begin
        ;; Ensure amount is valid
        (asserts! (>= amount u0) (err ERR_INVALID_AMOUNT))
        
        ;; Validate spender address
        (asserts! (not (is-eq spender 'SP000000000000000000002Q6VF78)) (err ERR_INVALID_SPENDER))
        (asserts! (not (is-eq spender tx-sender)) (err ERR_INVALID_SPENDER))
        
        ;; Set allowance
        (map-set allowances { owner: tx-sender, spender: spender } amount)
        (ok true)
    )
)

;; FUNCTIONALITY 3: Transfer tokens on behalf of another principal (using allowance)
(define-public (transfer-from (owner principal) (recipient principal) (amount uint))
    (begin
        ;; Ensure amount is greater than zero
        (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
        
        ;; Ensure recipient is valid
        (asserts! (not (is-eq recipient 'SP000000000000000000002Q6VF78)) (err ERR_INVALID_RECIPIENT))
        
        ;; Ensure owner is valid
        (asserts! (not (is-eq owner 'SP000000000000000000002Q6VF78)) (err ERR_INVALID_SPENDER))
        
        ;; Check allowance
        (let ((current-allowance (default-to u0 (map-get? allowances { owner: owner, spender: tx-sender }))))
            (asserts! (>= current-allowance amount) (err ERR_ALLOWANCE_EXCEEDED))
            
            ;; Check if owner has locked tokens
            (match (map-get? token-locks { owner: owner })
                lock (asserts! 
                    (or 
                        (< (get amount lock) amount) 
                        (>= block-height (get unlock-height lock))
                    ) 
                    (err ERR_TOKENS_LOCKED))
                true
            )
            
            ;; Ensure the owner has enough balance
            (let ((owner-balance (default-to u0 (map-get? holdings owner))))
                (asserts! (>= owner-balance amount) (err ERR_BALANCE_LOW))
                
                ;; Update owner's balance
                (map-set holdings owner (- owner-balance amount))
                
                ;; Update recipient's balance
                (let ((recipient-balance (default-to u0 (map-get? holdings recipient))))
                    (map-set holdings recipient (+ recipient-balance amount))
                    
                    ;; Update allowance
                    (map-set allowances 
                        { owner: owner, spender: tx-sender } 
                        (- current-allowance amount)
                    )
                    (ok true)
                )
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

;; Get information about locked tokens for a principal
(define-read-only (get-lock-info (owner principal))
    (map-get? token-locks { owner: owner })
)

;; Get allowance for a spender from an owner
(define-read-only (get-allowance (owner principal) (spender principal))
    (default-to u0 (map-get? allowances { owner: owner, spender: spender }))
)