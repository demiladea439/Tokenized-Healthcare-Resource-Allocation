;; Usage Tracking Contract
;; Monitors consumption of resources

(define-data-var admin principal tx-sender)

;; Usage records
(define-map usage-records
  { usage-id: (string-ascii 64) }
  {
    facility-id: (string-ascii 64),
    resource-id: (string-ascii 64),
    quantity: uint,
    patient-id: (string-ascii 64),
    department: (string-ascii 64),
    timestamp: uint,
    allocation-id: (optional (string-ascii 64))
  }
)

;; Aggregated usage statistics
(define-map usage-stats
  { facility-id: (string-ascii 64), resource-id: (string-ascii 64), period: uint }
  {
    total-quantity: uint,
    count: uint,
    last-updated: uint
  }
)

;; Public functions

(define-public (record-usage
    (usage-id (string-ascii 64))
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64))
    (quantity uint)
    (patient-id (string-ascii 64))
    (department (string-ascii 64))
    (allocation-id (optional (string-ascii 64))))
  (begin
    ;; In a real implementation, we would verify the facility is authorized
    (asserts! (is-none (map-get? usage-records { usage-id: usage-id })) (err u100))

    ;; Record the usage
    (map-set usage-records
      { usage-id: usage-id }
      {
        facility-id: facility-id,
        resource-id: resource-id,
        quantity: quantity,
        patient-id: patient-id,
        department: department,
        timestamp: block-height,
        allocation-id: allocation-id
      }
    )

    ;; Update daily stats (period = 1)
    (update-stats facility-id resource-id u1 quantity)

    ;; Update weekly stats (period = 2)
    (update-stats facility-id resource-id u2 quantity)

    ;; Update monthly stats (period = 3)
    (update-stats facility-id resource-id u3 quantity)

    (ok true)
  )
)

(define-private (update-stats
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64))
    (period uint)
    (quantity uint))
  (let (
    (current-stats (default-to
      { total-quantity: u0, count: u0, last-updated: u0 }
      (map-get? usage-stats { facility-id: facility-id, resource-id: resource-id, period: period })))
  )
    (map-set usage-stats
      { facility-id: facility-id, resource-id: resource-id, period: period }
      {
        total-quantity: (+ (get total-quantity current-stats) quantity),
        count: (+ (get count current-stats) u1),
        last-updated: block-height
      }
    )
  )
)

(define-read-only (get-usage-record (usage-id (string-ascii 64)))
  (map-get? usage-records { usage-id: usage-id })
)

(define-read-only (get-usage-stats
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64))
    (period uint))
  (map-get? usage-stats { facility-id: facility-id, resource-id: resource-id, period: period })
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
