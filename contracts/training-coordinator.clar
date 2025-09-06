;; Training Coordinator Contract for Workforce Development Alliance
;; This contract manages training programs, participant enrollment, and certification processes

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))
(define-constant err-invalid-data (err u203))
(define-constant err-unauthorized (err u204))
(define-constant err-program-full (err u205))
(define-constant err-not-enrolled (err u206))
(define-constant err-program-inactive (err u207))
(define-constant err-already-completed (err u208))

;; Data Variables
(define-data-var next-program-id uint u1)
(define-data-var next-enrollment-id uint u1)
(define-data-var next-certificate-id uint u1)
(define-data-var next-provider-id uint u1)

;; Data Maps

;; Training providers registry
(define-map training-providers
    { provider-id: uint }
    {
        name: (string-ascii 100),
        contact-info: (string-ascii 100),
        location: (string-ascii 50),
        specialties: (list 5 (string-ascii 50)),
        verified: bool,
        rating: uint, ;; 1-10 scale
        total-programs: uint,
        registered-by: principal,
        registered-at: uint,
        is-active: bool
    }
)

;; Training programs
(define-map training-programs
    { program-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 300),
        provider-id: uint,
        skill-category: (string-ascii 50),
        difficulty-level: uint, ;; 1-5 scale (1=beginner, 5=expert)
        duration-hours: uint,
        max-participants: uint,
        current-participants: uint,
        cost: uint, ;; in micro-STX
        location: (string-ascii 50),
        start-date: uint,
        end-date: uint,
        prerequisites: (string-ascii 200),
        learning-outcomes: (string-ascii 300),
        is-active: bool,
        created-at: uint
    }
)

;; Training enrollments
(define-map enrollments
    { enrollment-id: uint }
    {
        participant: principal,
        program-id: uint,
        enrolled-at: uint,
        status: (string-ascii 20), ;; "enrolled", "in-progress", "completed", "dropped"
        progress-percentage: uint, ;; 0-100
        start-date: uint,
        completion-date: (optional uint),
        final-score: (optional uint), ;; 0-100
        feedback: (optional (string-ascii 200))
    }
)

;; Certificates
(define-map certificates
    { certificate-id: uint }
    {
        recipient: principal,
        program-id: uint,
        enrollment-id: uint,
        issued-at: uint,
        issuer: principal,
        certificate-hash: (string-ascii 64), ;; SHA-256 hash for verification
        skill-level-achieved: uint, ;; 1-10 scale
        expiry-date: (optional uint),
        is-valid: bool
    }
)

;; Participant profiles
(define-map participants
    { participant: principal }
    {
        name: (string-ascii 100),
        location: (string-ascii 50),
        current-skill-level: uint, ;; 1-10 scale
        career-goals: (string-ascii 200),
        total-programs-completed: uint,
        total-certificates: uint,
        registered-at: uint,
        is-active: bool
    }
)

;; Program schedules
(define-map program-schedules
    { program-id: uint }
    {
        sessions: (list 20 {
            session-date: uint,
            duration-hours: uint,
            topic: (string-ascii 100),
            instructor: (string-ascii 50)
        }),
        total-sessions: uint,
        completed-sessions: uint
    }
)

;; Read-only functions

(define-read-only (get-training-provider (provider-id uint))
    (map-get? training-providers { provider-id: provider-id })
)

(define-read-only (get-training-program (program-id uint))
    (map-get? training-programs { program-id: program-id })
)

(define-read-only (get-enrollment (enrollment-id uint))
    (map-get? enrollments { enrollment-id: enrollment-id })
)

(define-read-only (get-certificate (certificate-id uint))
    (map-get? certificates { certificate-id: certificate-id })
)

(define-read-only (get-participant (participant principal))
    (map-get? participants { participant: participant })
)

(define-read-only (get-program-schedule (program-id uint))
    (map-get? program-schedules { program-id: program-id })
)

(define-read-only (get-next-program-id)
    (var-get next-program-id)
)

(define-read-only (get-next-enrollment-id)
    (var-get next-enrollment-id)
)

(define-read-only (get-next-certificate-id)
    (var-get next-certificate-id)
)

(define-read-only (get-next-provider-id)
    (var-get next-provider-id)
)

;; Public functions

;; Register as a training provider
(define-public (register-training-provider
    (name (string-ascii 100))
    (contact-info (string-ascii 100))
    (location (string-ascii 50))
    (specialties (list 5 (string-ascii 50)))
)
    (let
        (
            (provider-id (var-get next-provider-id))
        )
        (asserts! (> (len name) u0) err-invalid-data)
        (asserts! (> (len contact-info) u0) err-invalid-data)
        
        (map-set training-providers
            { provider-id: provider-id }
            {
                name: name,
                contact-info: contact-info,
                location: location,
                specialties: specialties,
                verified: false,
                rating: u5, ;; default rating
                total-programs: u0,
                registered-by: tx-sender,
                registered-at: stacks-block-height,
                is-active: true
            }
        )
        
        (var-set next-provider-id (+ provider-id u1))
        (ok provider-id)
    )
)

;; Register as a participant
(define-public (register-participant
    (name (string-ascii 100))
    (location (string-ascii 50))
    (current-skill-level uint)
    (career-goals (string-ascii 200))
)
    (begin
        (asserts! (is-none (map-get? participants { participant: tx-sender })) err-already-exists)
        (asserts! (> (len name) u0) err-invalid-data)
        (asserts! (and (>= current-skill-level u1) (<= current-skill-level u10)) err-invalid-data)
        
        (map-set participants
            { participant: tx-sender }
            {
                name: name,
                location: location,
                current-skill-level: current-skill-level,
                career-goals: career-goals,
                total-programs-completed: u0,
                total-certificates: u0,
                registered-at: stacks-block-height,
                is-active: true
            }
        )
        (ok true)
    )
)

;; Create a training program
(define-public (create-training-program
    (title (string-ascii 100))
    (description (string-ascii 300))
    (provider-id uint)
    (skill-category (string-ascii 50))
    (difficulty-level uint)
    (duration-hours uint)
    (max-participants uint)
    (cost uint)
    (location (string-ascii 50))
    (start-date uint)
    (end-date uint)
    (prerequisites (string-ascii 200))
    (learning-outcomes (string-ascii 300))
)
    (let
        (
            (program-id (var-get next-program-id))
            (provider-info (unwrap! (map-get? training-providers { provider-id: provider-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get registered-by provider-info)) err-unauthorized)
        (asserts! (get is-active provider-info) err-program-inactive)
        (asserts! (> (len title) u0) err-invalid-data)
        (asserts! (and (>= difficulty-level u1) (<= difficulty-level u5)) err-invalid-data)
        (asserts! (> duration-hours u0) err-invalid-data)
        (asserts! (> max-participants u0) err-invalid-data)
        (asserts! (< start-date end-date) err-invalid-data)
        
        (map-set training-programs
            { program-id: program-id }
            {
                title: title,
                description: description,
                provider-id: provider-id,
                skill-category: skill-category,
                difficulty-level: difficulty-level,
                duration-hours: duration-hours,
                max-participants: max-participants,
                current-participants: u0,
                cost: cost,
                location: location,
                start-date: start-date,
                end-date: end-date,
                prerequisites: prerequisites,
                learning-outcomes: learning-outcomes,
                is-active: true,
                created-at: stacks-block-height
            }
        )
        
        ;; Update provider's total programs count
        (map-set training-providers
            { provider-id: provider-id }
            (merge provider-info { total-programs: (+ (get total-programs provider-info) u1) })
        )
        
        (var-set next-program-id (+ program-id u1))
        (ok program-id)
    )
)

;; Enroll in a training program
(define-public (enroll-in-program (program-id uint))
    (let
        (
            (enrollment-id (var-get next-enrollment-id))
            (program-info (unwrap! (map-get? training-programs { program-id: program-id }) err-not-found))
            (participant-info (unwrap! (map-get? participants { participant: tx-sender }) err-not-found))
        )
        (asserts! (get is-active program-info) err-program-inactive)
        (asserts! (get is-active participant-info) err-unauthorized)
        (asserts! (< (get current-participants program-info) (get max-participants program-info)) err-program-full)
        
        (map-set enrollments
            { enrollment-id: enrollment-id }
            {
                participant: tx-sender,
                program-id: program-id,
                enrolled-at: stacks-block-height,
                status: "enrolled",
                progress-percentage: u0,
                start-date: (get start-date program-info),
                completion-date: none,
                final-score: none,
                feedback: none
            }
        )
        
        ;; Update program's current participants count
        (map-set training-programs
            { program-id: program-id }
            (merge program-info { current-participants: (+ (get current-participants program-info) u1) })
        )
        
        (var-set next-enrollment-id (+ enrollment-id u1))
        (ok enrollment-id)
    )
)

;; Update enrollment progress
(define-public (update-progress (enrollment-id uint) (progress-percentage uint) (status (string-ascii 20)))
    (let
        (
            (enrollment-info (unwrap! (map-get? enrollments { enrollment-id: enrollment-id }) err-not-found))
            (program-info (unwrap! (map-get? training-programs { program-id: (get program-id enrollment-info) }) err-not-found))
            (provider-info (unwrap! (map-get? training-providers { provider-id: (get provider-id program-info) }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get registered-by provider-info)) err-unauthorized)
        (asserts! (<= progress-percentage u100) err-invalid-data)
        
        (map-set enrollments
            { enrollment-id: enrollment-id }
            (merge enrollment-info {
                progress-percentage: progress-percentage,
                status: status
            })
        )
        (ok true)
    )
)

;; Complete training program
(define-public (complete-program (enrollment-id uint) (final-score uint) (feedback (optional (string-ascii 200))))
    (let
        (
            (enrollment-info (unwrap! (map-get? enrollments { enrollment-id: enrollment-id }) err-not-found))
            (program-info (unwrap! (map-get? training-programs { program-id: (get program-id enrollment-info) }) err-not-found))
            (provider-info (unwrap! (map-get? training-providers { provider-id: (get provider-id program-info) }) err-not-found))
            (participant-info (unwrap! (map-get? participants { participant: (get participant enrollment-info) }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get registered-by provider-info)) err-unauthorized)
        (asserts! (<= final-score u100) err-invalid-data)
        (asserts! (not (is-eq (get status enrollment-info) "completed")) err-already-completed)
        
        (map-set enrollments
            { enrollment-id: enrollment-id }
            (merge enrollment-info {
                status: "completed",
                progress-percentage: u100,
                completion-date: (some stacks-block-height),
                final-score: (some final-score),
                feedback: feedback
            })
        )
        
        ;; Update participant's completion count
        (map-set participants
            { participant: (get participant enrollment-info) }
            (merge participant-info { total-programs-completed: (+ (get total-programs-completed participant-info) u1) })
        )
        
        (ok true)
    )
)

;; Issue certificate
(define-public (issue-certificate
    (enrollment-id uint)
    (certificate-hash (string-ascii 64))
    (skill-level-achieved uint)
    (expiry-date (optional uint))
)
    (let
        (
            (certificate-id (var-get next-certificate-id))
            (enrollment-info (unwrap! (map-get? enrollments { enrollment-id: enrollment-id }) err-not-found))
            (program-info (unwrap! (map-get? training-programs { program-id: (get program-id enrollment-info) }) err-not-found))
            (provider-info (unwrap! (map-get? training-providers { provider-id: (get provider-id program-info) }) err-not-found))
            (participant-info (unwrap! (map-get? participants { participant: (get participant enrollment-info) }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get registered-by provider-info)) err-unauthorized)
        (asserts! (is-eq (get status enrollment-info) "completed") err-not-found)
        (asserts! (and (>= skill-level-achieved u1) (<= skill-level-achieved u10)) err-invalid-data)
        (asserts! (> (len certificate-hash) u0) err-invalid-data)
        
        (map-set certificates
            { certificate-id: certificate-id }
            {
                recipient: (get participant enrollment-info),
                program-id: (get program-id enrollment-info),
                enrollment-id: enrollment-id,
                issued-at: stacks-block-height,
                issuer: tx-sender,
                certificate-hash: certificate-hash,
                skill-level-achieved: skill-level-achieved,
                expiry-date: expiry-date,
                is-valid: true
            }
        )
        
        ;; Update participant's certificate count
        (map-set participants
            { participant: (get participant enrollment-info) }
            (merge participant-info { total-certificates: (+ (get total-certificates participant-info) u1) })
        )
        
        (var-set next-certificate-id (+ certificate-id u1))
        (ok certificate-id)
    )
)

;; Verify certificate
(define-read-only (verify-certificate (certificate-id uint) (expected-hash (string-ascii 64)))
    (match (map-get? certificates { certificate-id: certificate-id })
        cert-info (and 
                    (get is-valid cert-info)
                    (is-eq (get certificate-hash cert-info) expected-hash)
                    (match (get expiry-date cert-info)
                        expiry (< stacks-block-height expiry)
                        true
                    )
                  )
        false
    )
)

;; Update provider rating (admin function)
(define-public (update-provider-rating (provider-id uint) (rating uint))
    (let
        (
            (provider-info (unwrap! (map-get? training-providers { provider-id: provider-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (and (>= rating u1) (<= rating u10)) err-invalid-data)
        
        (map-set training-providers
            { provider-id: provider-id }
            (merge provider-info { rating: rating })
        )
        (ok true)
    )
)

;; Verify training provider (admin function)
(define-public (verify-training-provider (provider-id uint))
    (let
        (
            (provider-info (unwrap! (map-get? training-providers { provider-id: provider-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set training-providers
            { provider-id: provider-id }
            (merge provider-info { verified: true })
        )
        (ok true)
    )
)

;; Deactivate training program
(define-public (deactivate-program (program-id uint))
    (let
        (
            (program-info (unwrap! (map-get? training-programs { program-id: program-id }) err-not-found))
            (provider-info (unwrap! (map-get? training-providers { provider-id: (get provider-id program-info) }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get registered-by provider-info)) err-unauthorized)
        
        (map-set training-programs
            { program-id: program-id }
            (merge program-info { is-active: false })
        )
        (ok true)
    )
)

;; Revoke certificate (admin function)
(define-public (revoke-certificate (certificate-id uint))
    (let
        (
            (certificate-info (unwrap! (map-get? certificates { certificate-id: certificate-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set certificates
            { certificate-id: certificate-id }
            (merge certificate-info { is-valid: false })
        )
        (ok true)
    )
)

;; Drop out of program
(define-public (drop-from-program (enrollment-id uint))
    (let
        (
            (enrollment-info (unwrap! (map-get? enrollments { enrollment-id: enrollment-id }) err-not-found))
            (program-info (unwrap! (map-get? training-programs { program-id: (get program-id enrollment-info) }) err-not-found))
        )
        (asserts! (is-eq tx-sender (get participant enrollment-info)) err-unauthorized)
        (asserts! (not (is-eq (get status enrollment-info) "completed")) err-already-completed)
        
        (map-set enrollments
            { enrollment-id: enrollment-id }
            (merge enrollment-info { status: "dropped" })
        )
        
        ;; Update program's current participants count
        (map-set training-programs
            { program-id: (get program-id enrollment-info) }
            (merge program-info { current-participants: (- (get current-participants program-info) u1) })
        )
        
        (ok true)
    )
)

;; title: training-coordinator
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

