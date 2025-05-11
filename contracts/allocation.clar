;; Allocation Contract
;; Manages distribution of resources based on priority

(define-data-var admin principal tx-sender)

;; Priority levels: 1 (highest) to 5 (lowest)
(define-map facility-priority
  { facility-id: (string-ascii 64) }
  { priority-level: uint }
)

;; Allocation requests
(define-map allocation-requests
  { request-id: (string-ascii 64) }
  {
    facility-id: (string-ascii 64),
    resource-id: (string-ascii 64),
    quantity-requested: uint,
    status: uint,  ;; 0=pending, 1=approved, 2=fulfilled, 3=rejected
    request-date: uint,
    fulfillment-date: uint
  }
)

;; Allocation records
(define-map allocations
  { allocation-id: (string-ascii 64) }
  {
    request-id: (string-ascii 64),
    source-facility-id: (string-ascii 64),
    destination-facility-id: (string-ascii 64),
    resource-id: (string-ascii 64),
    quantity: uint,
    allocation-date: uint,
    status: uint  ;; 0=allocated, 1=in-transit, 2=delivered
  }
)

;; Public functions

(define-public (set-facility-priority
    (facility-id (string-ascii 64))
    (priority-level uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (and (>= priority-level u1) (<= priority-level u5)) (err u100))

    (map-set facility-priority
      { facility-id: facility-id }
      { priority-level: priority-level }
    )
    (ok true)
  )
)

(define-public (request-allocation
    (request-id (string-ascii 64))
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64))
    (quantity-requested uint))
  (begin
    ;; In a real implementation, we would verify the facility is authorized
    (asserts! (is-none (map-get? allocation-requests { request-id: request-id })) (err u101))

    (map-set allocation-requests
      { request-id: request-id }
      {
        facility-id: facility-id,
        resource-id: resource-id,
        quantity-requested: quantity-requested,
        status: u0,
        request-date: block-height,
        fulfillment-date: u0
      }
    )
    (ok true)
  )
)

(define-public (approve-request (request-id (string-ascii 64)))
  (let ((request (unwrap! (map-get? allocation-requests { request-id: request-id }) (err u404))))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-eq (get status request) u0) (err u102))

    (map-set allocation-requests
      { request-id: request-id }
      (merge request { status: u1 })
    )
    (ok true)
  )
)

(define-public (create-allocation
    (allocation-id (string-ascii 64))
    (request-id (string-ascii 64))
    (source-facility-id (string-ascii 64))
    (quantity uint))
  (let ((request (unwrap! (map-get? allocation-requests { request-id: request-id }) (err u404))))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-eq (get status request) u1) (err u102))

    (map-set allocations
      { allocation-id: allocation-id }
      {
        request-id: request-id,
        source-facility-id: source-facility-id,
        destination-facility-id: (get facility-id request),
        resource-id: (get resource-id request),
        quantity: quantity,
        allocation-date: block-height,
        status: u0
      }
    )
    (ok true)
  )
)

(define-public (update-allocation-status
    (allocation-id (string-ascii 64))
    (new-status uint))
  (let ((allocation (unwrap! (map-get? allocations { allocation-id: allocation-id }) (err u404))))
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (and (>= new-status u0) (<= new-status u2)) (err u103))

    (map-set allocations
      { allocation-id: allocation-id }
      (merge allocation { status: new-status })
    )

    ;; If delivered, update the request status
    (if (is-eq new-status u2)
      (let ((request (unwrap! (map-get? allocation-requests { request-id: (get request-id allocation) }) (err u404))))
        (map-set allocation-requests
          { request-id: (get request-id allocation) }
          (merge request {
            status: u2,
            fulfillment-date: block-height
          })
        )
      )
      true
    )

    (ok true)
  )
)

(define-read-only (get-facility-priority (facility-id (string-ascii 64)))
  (default-to { priority-level: u5 } (map-get? facility-priority { facility-id: facility-id }))
)

(define-read-only (get-request (request-id (string-ascii 64)))
  (map-get? allocation-requests { request-id: request-id })
)

(define-read-only (get-allocation (allocation-id (string-ascii 64)))
  (map-get? allocations { allocation-id: allocation-id })
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
