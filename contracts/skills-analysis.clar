;; Skills Analysis Contract for Workforce Development Alliance
;; This contract handles skill demand registration, supply tracking, and gap analysis

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-unauthorized (err u104))

;; Data Variables
(define-data-var next-skill-id uint u1)
(define-data-var next-demand-id uint u1)
(define-data-var next-supply-id uint u1)
(define-data-var next-gap-id uint u1)

;; Data Maps

;; Skills registry - tracks all skills in the system
(define-map skills
    { skill-id: uint }
    {
        name: (string-ascii 50),
        category: (string-ascii 30),
        description: (string-ascii 200),
        created-by: principal,
        created-at: uint,
        is-active: bool
    }
)

;; Skill demands from employers
(define-map skill-demands
    { demand-id: uint }
    {
        skill-id: uint,
        employer: principal,
        demand-level: uint, ;; 1-10 scale
        urgency: uint, ;; 1-5 scale (1=low, 5=critical)
        location: (string-ascii 50),
        salary-range-min: uint,
        salary-range-max: uint,
        required-experience: uint, ;; years
        created-at: uint,
        expires-at: uint,
        is-active: bool
    }
)

;; Skill supply from workforce
(define-map skill-supplies
    { supply-id: uint }
    {
        skill-id: uint,
        provider: principal,
        proficiency-level: uint, ;; 1-10 scale
        experience-years: uint,
        location: (string-ascii 50),
        availability: bool,
        last-updated: uint,
        certifications: (list 10 (string-ascii 100))
    }
)

;; Identified skill gaps
(define-map skill-gaps
    { gap-id: uint }
    {
        skill-id: uint,
        total-demand: uint,
        total-supply: uint,
        gap-severity: uint, ;; 1-10 scale
        affected-locations: (list 10 (string-ascii 50)),
        recommended-actions: (string-ascii 300),
        created-at: uint,
        last-updated: uint
    }
)

;; Employer registrations
(define-map registered-employers
    { employer: principal }
    {
        company-name: (string-ascii 100),
        industry: (string-ascii 50),
        location: (string-ascii 50),
        verified: bool,
        registered-at: uint
    }
)

;; Worker/Supply provider registrations
(define-map registered-providers
    { provider: principal }
    {
        name: (string-ascii 100),
        location: (string-ascii 50),
        verified: bool,
        registered-at: uint,
        total-skills: uint
    }
)

;; Read-only functions

(define-read-only (get-skill (skill-id uint))
    (map-get? skills { skill-id: skill-id })
)

(define-read-only (get-skill-demand (demand-id uint))
    (map-get? skill-demands { demand-id: demand-id })
)

(define-read-only (get-skill-supply (supply-id uint))
    (map-get? skill-supplies { supply-id: supply-id })
)

(define-read-only (get-skill-gap (gap-id uint))
    (map-get? skill-gaps { gap-id: gap-id })
)

(define-read-only (get-employer-info (employer principal))
    (map-get? registered-employers { employer: employer })
)

(define-read-only (get-provider-info (provider principal))
    (map-get? registered-providers { provider: provider })
)

(define-read-only (get-next-skill-id)
    (var-get next-skill-id)
)

(define-read-only (get-next-demand-id)
    (var-get next-demand-id)
)

(define-read-only (get-next-supply-id)
    (var-get next-supply-id)
)

(define-read-only (get-next-gap-id)
    (var-get next-gap-id)
)

;; Public functions

;; Register a new skill in the system
(define-public (register-skill (name (string-ascii 50)) (category (string-ascii 30)) (description (string-ascii 200)))
    (let
        (
            (skill-id (var-get next-skill-id))
        )
        (asserts! (> (len name) u0) err-invalid-data)
        (asserts! (> (len category) u0) err-invalid-data)
        
        (map-set skills
            { skill-id: skill-id }
            {
                name: name,
                category: category,
                description: description,
                created-by: tx-sender,
                created-at: stacks-block-height,
                is-active: true
            }
        )
        
        (var-set next-skill-id (+ skill-id u1))
        (ok skill-id)
    )
)

;; Register as an employer
(define-public (register-employer (company-name (string-ascii 100)) (industry (string-ascii 50)) (location (string-ascii 50)))
    (begin
        (asserts! (is-none (map-get? registered-employers { employer: tx-sender })) err-already-exists)
        (asserts! (> (len company-name) u0) err-invalid-data)
        
        (map-set registered-employers
            { employer: tx-sender }
            {
                company-name: company-name,
                industry: industry,
                location: location,
                verified: false,
                registered-at: stacks-block-height
            }
        )
        (ok true)
    )
)

;; Register as a skill provider
(define-public (register-provider (name (string-ascii 100)) (location (string-ascii 50)))
    (begin
        (asserts! (is-none (map-get? registered-providers { provider: tx-sender })) err-already-exists)
        (asserts! (> (len name) u0) err-invalid-data)
        
        (map-set registered-providers
            { provider: tx-sender }
            {
                name: name,
                location: location,
                verified: false,
                registered-at: stacks-block-height,
                total-skills: u0
            }
        )
        (ok true)
    )
)

;; Register skill demand by employer
(define-public (register-skill-demand 
    (skill-id uint) 
    (demand-level uint) 
    (urgency uint) 
    (location (string-ascii 50))
    (salary-range-min uint)
    (salary-range-max uint)
    (required-experience uint)
    (duration-blocks uint)
)
    (let
        (
            (demand-id (var-get next-demand-id))
        )
        (asserts! (is-some (map-get? registered-employers { employer: tx-sender })) err-unauthorized)
        (asserts! (is-some (map-get? skills { skill-id: skill-id })) err-not-found)
        (asserts! (and (>= demand-level u1) (<= demand-level u10)) err-invalid-data)
        (asserts! (and (>= urgency u1) (<= urgency u5)) err-invalid-data)
        (asserts! (<= salary-range-min salary-range-max) err-invalid-data)
        
        (map-set skill-demands
            { demand-id: demand-id }
            {
                skill-id: skill-id,
                employer: tx-sender,
                demand-level: demand-level,
                urgency: urgency,
                location: location,
                salary-range-min: salary-range-min,
                salary-range-max: salary-range-max,
                required-experience: required-experience,
                created-at: stacks-block-height,
                expires-at: (+ stacks-block-height duration-blocks),
                is-active: true
            }
        )
        
        (var-set next-demand-id (+ demand-id u1))
        (ok demand-id)
    )
)

;; Register skill supply by provider
(define-public (register-skill-supply
    (skill-id uint)
    (proficiency-level uint)
    (experience-years uint)
    (location (string-ascii 50))
    (availability bool)
    (certifications (list 10 (string-ascii 100)))
)
    (let
        (
            (supply-id (var-get next-supply-id))
            (provider-info (unwrap! (map-get? registered-providers { provider: tx-sender }) err-unauthorized))
        )
        (asserts! (is-some (map-get? skills { skill-id: skill-id })) err-not-found)
        (asserts! (and (>= proficiency-level u1) (<= proficiency-level u10)) err-invalid-data)
        
        (map-set skill-supplies
            { supply-id: supply-id }
            {
                skill-id: skill-id,
                provider: tx-sender,
                proficiency-level: proficiency-level,
                experience-years: experience-years,
                location: location,
                availability: availability,
                last-updated: stacks-block-height,
                certifications: certifications
            }
        )
        
        ;; Update provider's total skills count
        (map-set registered-providers
            { provider: tx-sender }
            (merge provider-info { total-skills: (+ (get total-skills provider-info) u1) })
        )
        
        (var-set next-supply-id (+ supply-id u1))
        (ok supply-id)
    )
)

;; Analyze and create skill gap entry (admin function)
(define-public (create-skill-gap
    (skill-id uint)
    (total-demand uint)
    (total-supply uint)
    (affected-locations (list 10 (string-ascii 50)))
    (recommended-actions (string-ascii 300))
)
    (let
        (
            (gap-id (var-get next-gap-id))
            (gap-severity (if (> total-demand total-supply)
                            (let ((calc-severity (/ (* (- total-demand total-supply) u10) (if (> total-demand u0) total-demand u1))))
                                (if (> calc-severity u10) u10 calc-severity))
                            u0))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? skills { skill-id: skill-id })) err-not-found)
        
        (map-set skill-gaps
            { gap-id: gap-id }
            {
                skill-id: skill-id,
                total-demand: total-demand,
                total-supply: total-supply,
                gap-severity: gap-severity,
                affected-locations: affected-locations,
                recommended-actions: recommended-actions,
                created-at: stacks-block-height,
                last-updated: stacks-block-height
            }
        )
        
        (var-set next-gap-id (+ gap-id u1))
        (ok gap-id)
    )
)

;; Update skill gap analysis
(define-public (update-skill-gap
    (gap-id uint)
    (total-demand uint)
    (total-supply uint)
    (recommended-actions (string-ascii 300))
)
    (let
        (
            (existing-gap (unwrap! (map-get? skill-gaps { gap-id: gap-id }) err-not-found))
            (gap-severity (if (> total-demand total-supply)
                            (let ((calc-severity (/ (* (- total-demand total-supply) u10) (if (> total-demand u0) total-demand u1))))
                                (if (> calc-severity u10) u10 calc-severity))
                            u0))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set skill-gaps
            { gap-id: gap-id }
            (merge existing-gap {
                total-demand: total-demand,
                total-supply: total-supply,
                gap-severity: gap-severity,
                recommended-actions: recommended-actions,
                last-updated: stacks-block-height
            })
        )
        (ok true)
    )
)

;; Verify employer (admin function)
(define-public (verify-employer (employer principal))
    (let
        (
            (employer-info (unwrap! (map-get? registered-employers { employer: employer }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set registered-employers
            { employer: employer }
            (merge employer-info { verified: true })
        )
        (ok true)
    )
)

;; Verify provider (admin function)
(define-public (verify-provider (provider principal))
    (let
        (
            (provider-info (unwrap! (map-get? registered-providers { provider: provider }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set registered-providers
            { provider: provider }
            (merge provider-info { verified: true })
        )
        (ok true)
    )
)

;; Deactivate skill demand
(define-public (deactivate-skill-demand (demand-id uint))
    (let
        (
            (demand-info (unwrap! (map-get? skill-demands { demand-id: demand-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get employer demand-info)) err-unauthorized)
        
        (map-set skill-demands
            { demand-id: demand-id }
            (merge demand-info { is-active: false })
        )
        (ok true)
    )
)

;; Update skill supply availability
(define-public (update-supply-availability (supply-id uint) (availability bool))
    (let
        (
            (supply-info (unwrap! (map-get? skill-supplies { supply-id: supply-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get provider supply-info)) err-unauthorized)
        
        (map-set skill-supplies
            { supply-id: supply-id }
            (merge supply-info { 
                availability: availability,
                last-updated: stacks-block-height
            })
        )
        (ok true)
    )
)

;; title: skills-analysis
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

