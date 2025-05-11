;; Demand Forecasting Contract
;; Predicts resource requirements based on historical data

(define-data-var admin principal tx-sender)

;; Historical demand data
(define-map historical-demand
  { facility-id: (string-ascii 64), resource-id: (string-ascii 64), period: uint }
  {
    quantity: uint,
    timestamp: uint
  }
)

;; Forecasted demand
(define-map demand-forecast
  { facility-id: (string-ascii 64), resource-id: (string-ascii 64) }
  {
    daily-rate: uint,
    weekly-forecast: uint,
    monthly-forecast: uint,
    last-updated: uint
  }
)

;; Public functions

(define-public (record-demand
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64))
    (period uint)
    (quantity uint))
  (begin
    ;; In a real implementation, we would verify the caller is authorized

    (map-set historical-demand
      { facility-id: facility-id, resource-id: resource-id, period: period }
      {
        quantity: quantity,
        timestamp: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-forecast
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64))
    (daily-rate uint)
    (weekly-forecast uint)
    (monthly-forecast uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))

    (map-set demand-forecast
      { facility-id: facility-id, resource-id: resource-id }
      {
        daily-rate: daily-rate,
        weekly-forecast: weekly-forecast,
        monthly-forecast: monthly-forecast,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

(define-read-only (get-historical-demand
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64))
    (period uint))
  (map-get? historical-demand
    { facility-id: facility-id, resource-id: resource-id, period: period }
  )
)

(define-read-only (get-forecast
    (facility-id (string-ascii 64))
    (resource-id (string-ascii 64)))
  (map-get? demand-forecast
    { facility-id: facility-id, resource-id: resource-id }
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
