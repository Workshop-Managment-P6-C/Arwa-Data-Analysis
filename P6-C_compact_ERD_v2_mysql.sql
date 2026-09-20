-- P6-C compact ERD v0.4, MySQL 8.0.13+ version (24 tables). Adds training_session.title (bilingual JSON).
-- Run in MySQL Workbench: File > Open SQL Script, then Query > Execute (lightning icon).
-- Recreates the database p6c_workshop from scratch (drops the old one if it exists).
-- Already have v0.3 with data? Do NOT run this file. Run this instead, then reload the training seed:
--   ALTER TABLE training_session ADD COLUMN title JSON NULL AFTER group_code;
-- Differences from the PostgreSQL model: ids are CHAR(36) with DEFAULT (UUID()); timestamps are DATETIME (store UTC);
-- jsonb columns are JSON. MySQL has no exclusion constraints, so bay double-booking must be prevented in the service layer.
DROP DATABASE IF EXISTS p6c_workshop;
CREATE DATABASE p6c_workshop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE p6c_workshop;

CREATE TABLE `app_user` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `email` varchar(255) UNIQUE COMMENT 'required for staff, mentors and students; optional for customers',
  `password_hash` varchar(255) COMMENT 'NULL for CUSTOMER: customers cannot log in. Service rule: every other role must have a hash',
  `full_name` varchar(255) NOT NULL,
  `role` ENUM ('WORKSHOP_MANAGER', 'SERVICE_ADVISOR', 'TECHNICIAN', 'QUALITY_CHECKER', 'STOREKEEPER', 'PROCUREMENT', 'TRAINING_SUPERVISOR', 'MENTOR', 'STUDENT', 'FINANCE_VIEWER', 'AUDITOR', 'CUSTOMER') NOT NULL COMMENT 'one role per person in the MVP; permissions come from the RBAC matrix in code',
  `phone` varchar(255),
  `contact_preference` varchar(255) COMMENT 'PHONE, EMAIL or NONE (mainly for customers)',
  `store_code` varchar(255) COMMENT 'S1 or S2: organisational scope for storekeepers and procurement',
  `student_code` varchar(255) UNIQUE COMMENT 'STUDENT only, synthetic code',
  `specialty` varchar(255) COMMENT 'MENTOR only',
  `preferred_language` varchar(255) DEFAULT 'en' COMMENT 'en or ar',
  `is_synthetic` boolean DEFAULT true COMMENT 'demo data only, no real personal data',
  `is_active` boolean DEFAULT true,
  `is_archived` boolean DEFAULT false,
  `created_at` DATETIME DEFAULT (NOW()),
  `updated_at` DATETIME
);

CREATE TABLE `vehicle` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `customer_id` CHAR(36) NOT NULL COMMENT 'a user with role CUSTOMER',
  `plate_number` varchar(255),
  `vin` varchar(255) UNIQUE,
  `make` varchar(255),
  `model` varchar(255),
  `year` int,
  `current_mileage` int,
  `next_service_date` date COMMENT 'next_service_* and service_interval_km form the next-service rule',
  `next_service_mileage` int,
  `service_interval_km` int,
  `is_archived` boolean DEFAULT false,
  `created_at` DATETIME DEFAULT (NOW())
);

CREATE TABLE `bay` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `name` varchar(255) UNIQUE NOT NULL,
  `kind` varchar(255) COMMENT 'WORKSHOP, TRAINING or SHARED',
  `is_active` boolean DEFAULT true
);

CREATE TABLE `job_card` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `job_number` varchar(255) UNIQUE NOT NULL,
  `vehicle_id` CHAR(36) NOT NULL,
  `service_type` varchar(255),
  `priority` varchar(255),
  `complaint` text,
  `mileage_in` int,
  `stage` ENUM ('RECEIVED', 'IN_PROGRESS', 'QUALITY_CHECK', 'READY', 'DELIVERED') NOT NULL DEFAULT 'RECEIVED',
  `bay_id` CHAR(36),
  `technician_id` CHAR(36),
  `advisor_id` CHAR(36),
  `promised_at` DATETIME,
  `delivered_at` DATETIME,
  `created_at` DATETIME DEFAULT (NOW()),
  `created_by` CHAR(36),
  `updated_at` DATETIME,
  `updated_by` CHAR(36)
);

CREATE TABLE `job_stage` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `job_card_id` CHAR(36) NOT NULL,
  `from_stage` ENUM ('RECEIVED', 'IN_PROGRESS', 'QUALITY_CHECK', 'READY', 'DELIVERED'),
  `to_stage` ENUM ('RECEIVED', 'IN_PROGRESS', 'QUALITY_CHECK', 'READY', 'DELIVERED') NOT NULL,
  `changed_by` CHAR(36) NOT NULL,
  `note` text,
  `changed_at` DATETIME DEFAULT (NOW())
);

CREATE TABLE `work_item` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `job_card_id` CHAR(36) NOT NULL,
  `description` varchar(255) NOT NULL,
  `is_billable` boolean DEFAULT true,
  `approval` ENUM ('PENDING', 'APPROVED', 'DECLINED') DEFAULT 'PENDING' COMMENT 'billable work must not start before APPROVED',
  `approved_by` CHAR(36),
  `approved_at` DATETIME,
  `status` varchar(255) DEFAULT 'OPEN' COMMENT 'OPEN or DONE'
);

CREATE TABLE `labor_entry` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `job_card_id` CHAR(36) NOT NULL,
  `work_item_id` CHAR(36),
  `technician_id` CHAR(36) NOT NULL,
  `minutes` int NOT NULL COMMENT 'CHECK (minutes > 0)',
  `logged_at` DATETIME DEFAULT (NOW()),
  `note` varchar(255)
);

CREATE TABLE `bay_booking` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `bay_id` CHAR(36) NOT NULL,
  `starts_at` DATETIME NOT NULL,
  `ends_at` DATETIME NOT NULL,
  `source` ENUM ('JOB', 'SESSION') NOT NULL,
  `job_card_id` CHAR(36),
  `training_session_id` CHAR(36)
);

CREATE TABLE `part` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `sku` varchar(255) UNIQUE NOT NULL,
  `barcode` varchar(255) UNIQUE,
  `name` JSON NOT NULL COMMENT 'composite: {"en": "...", "ar": "..."}',
  `category` varchar(255),
  `compatible_models` JSON COMMENT 'list of make/model strings',
  `unit` varchar(255) DEFAULT 'pcs',
  `average_cost` numeric(12,2),
  `min_level` int DEFAULT 0,
  `max_level` int,
  `is_active` boolean DEFAULT true
);

CREATE TABLE `stock_movement` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `part_id` CHAR(36) NOT NULL,
  `store_code` varchar(255) NOT NULL DEFAULT 'S1' COMMENT 'S1 or S2 (the two demo stores)',
  `type` ENUM ('RECEIPT', 'ISSUE', 'RESERVATION', 'RELEASE', 'TRANSFER_OUT', 'TRANSFER_IN', 'COUNT_ADJUSTMENT', 'ADJUSTMENT', 'REVERSAL') NOT NULL,
  `quantity` int NOT NULL COMMENT 'signed: receipts positive, issues negative',
  `unit_cost` numeric(12,2),
  `reason` varchar(255) COMMENT 'required for ADJUSTMENT, COUNT_ADJUSTMENT and REVERSAL',
  `job_card_id` CHAR(36),
  `purchase_order_line_id` CHAR(36) COMMENT 'set on RECEIPT rows: this is the goods receipt',
  `reverses_id` CHAR(36),
  `counted_quantity` int COMMENT 'COUNT_ADJUSTMENT only',
  `system_quantity` int COMMENT 'ledger balance at count time, COUNT_ADJUSTMENT only',
  `created_by` CHAR(36) NOT NULL,
  `created_at` DATETIME DEFAULT (NOW())
);

CREATE TABLE `purchase_order` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `po_number` varchar(255) UNIQUE NOT NULL,
  `vendor_name` varchar(255) NOT NULL COMMENT 'vendor_name and vendor_contact_* form one composite attribute (replaces the Vendor table)',
  `vendor_contact_phone` varchar(255),
  `vendor_contact_email` varchar(255),
  `status` ENUM ('DRAFT', 'SUBMITTED', 'APPROVED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'REJECTED', 'CANCELLED') DEFAULT 'DRAFT',
  `total_amount` numeric(12,2),
  `approvals_required` int DEFAULT 1 COMMENT '2 when total_amount is above the configured threshold',
  `approval1_by` CHAR(36) COMMENT 'must differ from created_by',
  `approval1_at` DATETIME,
  `approval2_by` CHAR(36) COMMENT 'must differ from created_by and approval1_by',
  `approval2_at` DATETIME,
  `created_by` CHAR(36) NOT NULL,
  `created_at` DATETIME DEFAULT (NOW()),
  `submitted_at` DATETIME
);

CREATE TABLE `purchase_order_line` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `purchase_order_id` CHAR(36) NOT NULL,
  `part_id` CHAR(36) NOT NULL,
  `quantity` int NOT NULL,
  `unit_price` numeric(12,2),
  `received_quantity` int DEFAULT 0 COMMENT 'accepted quantity, equals the sum of RECEIPT movements for this line',
  `rejected_quantity` int DEFAULT 0
);

CREATE TABLE `invoice` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `invoice_number` varchar(255) UNIQUE NOT NULL,
  `job_card_id` CHAR(36) NOT NULL,
  `status` ENUM ('DRAFT', 'ISSUED', 'PAID', 'VOID') DEFAULT 'DRAFT',
  `subtotal` numeric(12,2),
  `discount` numeric(12,2) DEFAULT 0,
  `tax` numeric(12,2) DEFAULT 0,
  `total_amount` numeric(12,2),
  `issued_at` DATETIME,
  `payment_reference` varchar(255) COMMENT 'reference only, no real payments',
  `paid_amount` numeric(12,2),
  `paid_at` DATETIME
);

CREATE TABLE `invoice_line` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `invoice_id` CHAR(36) NOT NULL,
  `kind` ENUM ('LABOUR', 'PART', 'SUBLET') NOT NULL,
  `labor_entry_id` CHAR(36),
  `stock_movement_id` CHAR(36),
  `description` varchar(255),
  `quantity` numeric(10,2),
  `unit_price` numeric(12,2)
);

CREATE TABLE `course` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `code` varchar(255) UNIQUE NOT NULL,
  `name` JSON NOT NULL COMMENT 'composite: {"en": "...", "ar": "..."}',
  `required_sessions` int
);

CREATE TABLE `practical_task` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `course_id` CHAR(36) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text,
  `competency_code` varchar(255) NOT NULL COMMENT 'competency_code and competency_name form one composite attribute (replaces the Competency table)',
  `competency_name` JSON COMMENT '{"en": "...", "ar": "..."}'
);

CREATE TABLE `training_session` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `course_id` CHAR(36) NOT NULL,
  `group_code` varchar(255) NOT NULL COMMENT 'replaces TrainingGroup; matches enrollment.group_code',
  `title` JSON COMMENT 'composite: {"en": "Session 3: Replace front brake pads", "ar": "..."}. Sessions 2-6 cover course tasks 1-5',
  `bay_id` CHAR(36) NOT NULL,
  `mentor_id` CHAR(36) NOT NULL COMMENT 'a user with role MENTOR',
  `starts_at` DATETIME NOT NULL,
  `ends_at` DATETIME NOT NULL,
  `capacity` int,
  `status` ENUM ('PLANNED', 'CONFIRMED', 'COMPLETED', 'CANCELLED') DEFAULT 'PLANNED'
);

CREATE TABLE `enrollment` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `student_id` CHAR(36) NOT NULL COMMENT 'a user with role STUDENT',
  `course_id` CHAR(36) NOT NULL,
  `group_code` varchar(255) NOT NULL,
  `enrolled_at` DATETIME DEFAULT (NOW())
);

CREATE TABLE `attendance` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `training_session_id` CHAR(36) NOT NULL,
  `student_id` CHAR(36) NOT NULL,
  `status` ENUM ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED') NOT NULL,
  `recorded_by` CHAR(36) NOT NULL,
  `recorded_at` DATETIME DEFAULT (NOW())
);

CREATE TABLE `assessment` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `training_session_id` CHAR(36) NOT NULL,
  `student_id` CHAR(36) NOT NULL,
  `practical_task_id` CHAR(36) NOT NULL,
  `result` ENUM ('PASS', 'FAIL', 'NEEDS_IMPROVEMENT') NOT NULL,
  `time_on_task_minutes` int,
  `mentor_note` text,
  `entered_by` CHAR(36) NOT NULL COMMENT 'mentor',
  `signed_by` CHAR(36) COMMENT 'supervisor, must differ from entered_by',
  `signed_at` DATETIME
);

CREATE TABLE `certificate` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `student_id` CHAR(36) NOT NULL,
  `course_id` CHAR(36) NOT NULL,
  `token` varchar(255) UNIQUE NOT NULL COMMENT 'long random token for the public verification link',
  `status` ENUM ('ISSUED', 'REVOKED') DEFAULT 'ISSUED',
  `issued_at` DATETIME DEFAULT (NOW()),
  `revoked_at` DATETIME,
  `revoked_reason` varchar(255)
);

CREATE TABLE `attachment` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `owner_type` varchar(255) NOT NULL COMMENT 'JOB_CARD, ASSESSMENT, ...',
  `owner_id` CHAR(36) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `mime_type` varchar(255) NOT NULL,
  `size_bytes` int NOT NULL,
  `storage_key` varchar(255) NOT NULL COMMENT 'random name in private storage, never the original name',
  `uploaded_by` CHAR(36) NOT NULL,
  `uploaded_at` DATETIME DEFAULT (NOW())
);

CREATE TABLE `notification` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `user_id` CHAR(36) NOT NULL,
  `type` varchar(255),
  `body` varchar(255),
  `created_at` DATETIME DEFAULT (NOW()),
  `read_at` DATETIME
);

CREATE TABLE `prediction` (
  `id` CHAR(36) PRIMARY KEY DEFAULT (UUID()),
  `kind` varchar(255) NOT NULL COMMENT 'REORDER_SUGGESTION or TRAINING_RISK',
  `subject_type` varchar(255) NOT NULL,
  `subject_id` CHAR(36) NOT NULL,
  `inputs` JSON,
  `baseline_version` varchar(255) NOT NULL,
  `output` varchar(255),
  `explanation` text,
  `decision` varchar(255) COMMENT 'ACCEPTED, OVERRIDDEN, IGNORED',
  `decided_by` CHAR(36),
  `outcome` varchar(255),
  `created_at` DATETIME DEFAULT (NOW())
);

CREATE UNIQUE INDEX `enrollment_index_0` ON `enrollment` (`student_id`, `course_id`);

CREATE UNIQUE INDEX `attendance_index_1` ON `attendance` (`training_session_id`, `student_id`);

ALTER TABLE `app_user` COMMENT = 'Every person in the system in ONE table: staff, mentors, students and customers (told apart by role; the role also decides which front door, Workshop or Student Training, the user may enter). Purpose: one identity and access record, so RBAC, ownership checks and foreign keys all point to a single place.';

ALTER TABLE `vehicle` COMMENT = 'A customer vehicle. Purpose: keeps vehicle identity, service history and the next-service rule; one customer can own many vehicles.';

ALTER TABLE `bay` COMMENT = 'A physical workshop bay (4 in the demo). Purpose: the shared resource that both jobs and training sessions compete for.';

ALTER TABLE `job_card` COMMENT = 'One repair job for one vehicle, from reception to delivery. Purpose: the central record of the workshop workflow; everything billable or measured hangs off it.';

ALTER TABLE `job_stage` COMMENT = 'One row per stage change of a job. Purpose: the auditable stage timeline (who moved the job and when) and the source for turnaround and rework metrics.';

ALTER TABLE `work_item` COMMENT = 'One line of the job work checklist with its customer approval. Purpose: enforces the rule that no billable work starts before approval.';

ALTER TABLE `labor_entry` COMMENT = 'Time a technician logged on a job. Purpose: source for invoice labour lines and for labour-hour and utilisation metrics.';

ALTER TABLE `bay_booking` COMMENT = 'One shared bay calendar for jobs AND training sessions. Purpose: detect conflicts. PostgreSQL: add an exclusion constraint (btree_gist) on (bay_id, tstzrange(starts_at, ends_at)). MySQL: check overlaps in the service.';

ALTER TABLE `part` COMMENT = 'A spare part in the catalogue. Purpose: identity, cost and reorder levels; quantities are NOT stored here, they come from the ledger.';

ALTER TABLE `stock_movement` COMMENT = 'APPEND-ONLY stock ledger: every receipt, issue, reservation, adjustment, count and reversal. Purpose: on-hand and reserved stock are computed from it, so they always reconcile; a REVERSAL row records who undid what and why.';

ALTER TABLE `purchase_order` COMMENT = 'A purchase order to a vendor. Purpose: controlled replenishment; stores the vendor details and up to two approvals so the two-approval rule is data, not code.';

ALTER TABLE `purchase_order_line` COMMENT = 'One part and quantity on a purchase order. Purpose: what was ordered versus what was accepted or rejected on receipt.';

ALTER TABLE `invoice` COMMENT = 'The bill for a completed job, with its payment reference. Purpose: accounting-lite charges computed from logged labour and issued parts, not typed by hand.';

ALTER TABLE `invoice_line` COMMENT = 'One labour, part or sublet line on an invoice, pointing at its source. Purpose: lets invoice totals be recomputed from source records.';

ALTER TABLE `course` COMMENT = 'A practical training course. Purpose: groups tasks and sessions and defines what completion requires.';

ALTER TABLE `practical_task` COMMENT = 'A practical task in a course and the competency it proves. Purpose: the task library; competency coverage is computed from signed results on these tasks.';

ALTER TABLE `training_session` COMMENT = 'One scheduled class: course, group, session title, bay, mentor and time. Purpose: the unit that is checked for bay and mentor conflicts before it can be published.';

ALTER TABLE `enrollment` COMMENT = 'A student joining a course in a group. Purpose: says who takes which course and which group they belong to.';

ALTER TABLE `attendance` COMMENT = 'One student present, absent, late or excused in one session. Purpose: attendance rate and the training-risk flag.';

ALTER TABLE `assessment` COMMENT = 'A mentor result for one student on one task, then signed by the supervisor. Purpose: the evidence behind competencies and certificates; unsigned rows (signed_at is null) never count.';

ALTER TABLE `certificate` COMMENT = 'A certificate issued after all required signed results are met. Purpose: public verification through a random token, with revocation.';

ALTER TABLE `attachment` COMMENT = 'Metadata for an uploaded file (job photo, assessment evidence). Purpose: the file itself sits in private storage; this row controls who may download it.';

ALTER TABLE `notification` COMMENT = 'A message shown to a user (for example a purchase order awaiting approval). Purpose: communication inside the system.';

ALTER TABLE `prediction` COMMENT = 'One advisory suggestion (reorder quantity or training risk) with its inputs, rule version, explanation and the human decision. Purpose: makes the rule-based baseline explainable and measurable.';

ALTER TABLE `vehicle` ADD FOREIGN KEY (`customer_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `job_card` ADD FOREIGN KEY (`vehicle_id`) REFERENCES `vehicle` (`id`);

ALTER TABLE `job_card` ADD FOREIGN KEY (`bay_id`) REFERENCES `bay` (`id`);

ALTER TABLE `job_card` ADD FOREIGN KEY (`technician_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `job_card` ADD FOREIGN KEY (`advisor_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `job_card` ADD FOREIGN KEY (`created_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `job_card` ADD FOREIGN KEY (`updated_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `job_stage` ADD FOREIGN KEY (`job_card_id`) REFERENCES `job_card` (`id`);

ALTER TABLE `job_stage` ADD FOREIGN KEY (`changed_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `work_item` ADD FOREIGN KEY (`job_card_id`) REFERENCES `job_card` (`id`);

ALTER TABLE `work_item` ADD FOREIGN KEY (`approved_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `labor_entry` ADD FOREIGN KEY (`job_card_id`) REFERENCES `job_card` (`id`);

ALTER TABLE `labor_entry` ADD FOREIGN KEY (`work_item_id`) REFERENCES `work_item` (`id`);

ALTER TABLE `labor_entry` ADD FOREIGN KEY (`technician_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `bay_booking` ADD FOREIGN KEY (`bay_id`) REFERENCES `bay` (`id`);

ALTER TABLE `bay_booking` ADD FOREIGN KEY (`job_card_id`) REFERENCES `job_card` (`id`);

ALTER TABLE `bay_booking` ADD FOREIGN KEY (`training_session_id`) REFERENCES `training_session` (`id`);

ALTER TABLE `stock_movement` ADD FOREIGN KEY (`part_id`) REFERENCES `part` (`id`);

ALTER TABLE `stock_movement` ADD FOREIGN KEY (`job_card_id`) REFERENCES `job_card` (`id`);

ALTER TABLE `stock_movement` ADD FOREIGN KEY (`purchase_order_line_id`) REFERENCES `purchase_order_line` (`id`);

ALTER TABLE `stock_movement` ADD FOREIGN KEY (`reverses_id`) REFERENCES `stock_movement` (`id`);

ALTER TABLE `stock_movement` ADD FOREIGN KEY (`created_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `purchase_order` ADD FOREIGN KEY (`approval1_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `purchase_order` ADD FOREIGN KEY (`approval2_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `purchase_order` ADD FOREIGN KEY (`created_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `purchase_order_line` ADD FOREIGN KEY (`purchase_order_id`) REFERENCES `purchase_order` (`id`);

ALTER TABLE `purchase_order_line` ADD FOREIGN KEY (`part_id`) REFERENCES `part` (`id`);

ALTER TABLE `invoice` ADD FOREIGN KEY (`job_card_id`) REFERENCES `job_card` (`id`);

ALTER TABLE `invoice_line` ADD FOREIGN KEY (`invoice_id`) REFERENCES `invoice` (`id`);

ALTER TABLE `invoice_line` ADD FOREIGN KEY (`labor_entry_id`) REFERENCES `labor_entry` (`id`);

ALTER TABLE `invoice_line` ADD FOREIGN KEY (`stock_movement_id`) REFERENCES `stock_movement` (`id`);

ALTER TABLE `practical_task` ADD FOREIGN KEY (`course_id`) REFERENCES `course` (`id`);

ALTER TABLE `training_session` ADD FOREIGN KEY (`course_id`) REFERENCES `course` (`id`);

ALTER TABLE `training_session` ADD FOREIGN KEY (`bay_id`) REFERENCES `bay` (`id`);

ALTER TABLE `training_session` ADD FOREIGN KEY (`mentor_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `enrollment` ADD FOREIGN KEY (`student_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `enrollment` ADD FOREIGN KEY (`course_id`) REFERENCES `course` (`id`);

ALTER TABLE `attendance` ADD FOREIGN KEY (`training_session_id`) REFERENCES `training_session` (`id`);

ALTER TABLE `attendance` ADD FOREIGN KEY (`student_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `attendance` ADD FOREIGN KEY (`recorded_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `assessment` ADD FOREIGN KEY (`training_session_id`) REFERENCES `training_session` (`id`);

ALTER TABLE `assessment` ADD FOREIGN KEY (`student_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `assessment` ADD FOREIGN KEY (`practical_task_id`) REFERENCES `practical_task` (`id`);

ALTER TABLE `assessment` ADD FOREIGN KEY (`entered_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `assessment` ADD FOREIGN KEY (`signed_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `certificate` ADD FOREIGN KEY (`student_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `certificate` ADD FOREIGN KEY (`course_id`) REFERENCES `course` (`id`);

ALTER TABLE `attachment` ADD FOREIGN KEY (`uploaded_by`) REFERENCES `app_user` (`id`);

ALTER TABLE `notification` ADD FOREIGN KEY (`user_id`) REFERENCES `app_user` (`id`);

ALTER TABLE `prediction` ADD FOREIGN KEY (`decided_by`) REFERENCES `app_user` (`id`);
