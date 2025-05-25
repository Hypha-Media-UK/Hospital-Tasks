

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."staff_role" AS ENUM (
    'supervisor',
    'porter'
);


ALTER TYPE "public"."staff_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "timezone" "text" DEFAULT 'UTC'::"text" NOT NULL,
    "time_format" "text" DEFAULT '24h'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."app_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "department_id" "uuid" NOT NULL,
    "porter_id" "uuid",
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "shift_type" "text",
    CONSTRAINT "new_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."area_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."area_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "area_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."area_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."buildings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."buildings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."departments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "building_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_frequent" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."departments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_area_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_area_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_area_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_area_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_defaults" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_type" "text" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shift_defaults" OWNER TO "postgres";


COMMENT ON TABLE "public"."shift_defaults" IS 'Stores default shift times and colors';



CREATE TABLE IF NOT EXISTS "public"."shift_porter_pool" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_porter_pool" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_support_service_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "service_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_support_service_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_support_service_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_support_service_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_support_service_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_tasks" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "task_item_id" "uuid" NOT NULL,
    "porter_id" "uuid",
    "origin_department_id" "uuid",
    "destination_department_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "time_received" "text" DEFAULT '00:00'::"text" NOT NULL,
    "time_allocated" "text" DEFAULT '00:01'::"text" NOT NULL,
    "time_completed" "text" DEFAULT '00:20'::"text" NOT NULL,
    CONSTRAINT "shift_tasks_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."shift_tasks" OWNER TO "postgres";


COMMENT ON TABLE "public"."shift_tasks" IS 'Task tracking table with time fields as text to avoid timezone issues';



CREATE TABLE IF NOT EXISTS "public"."shift_tasks_backup" (
    "id" "uuid",
    "shift_id" "uuid",
    "task_item_id" "uuid",
    "porter_id" "uuid",
    "origin_department_id" "uuid",
    "destination_department_id" "uuid",
    "status" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "time_received" timestamp with time zone,
    "time_allocated" timestamp with time zone,
    "time_completed" timestamp with time zone
);


ALTER TABLE "public"."shift_tasks_backup" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shifts" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "supervisor_id" "uuid" NOT NULL,
    "shift_type" "text" NOT NULL,
    "start_time" timestamp with time zone DEFAULT "now"() NOT NULL,
    "end_time" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "shifts_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['day'::"text", 'night'::"text", 'week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."shifts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "role" "public"."staff_role" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "department_id" "uuid"
);


ALTER TABLE "public"."staff" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_department_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "staff_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."staff_department_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_service_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "service_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "shift_type" "text",
    CONSTRAINT "support_service_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."support_service_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_service_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "support_service_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."support_service_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."support_services" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."support_services" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_item_department_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_item_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "is_origin" boolean DEFAULT false,
    "is_destination" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_item_department_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_type_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_type_department_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_type_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "is_origin" boolean DEFAULT false,
    "is_destination" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_type_department_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_types" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_types" OWNER TO "postgres";


ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."area_cover_assignments"
    ADD CONSTRAINT "area_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_area_cover_assignment_id_port_key" UNIQUE ("area_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."buildings"
    ADD CONSTRAINT "buildings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_shift_id_department_id_key" UNIQUE ("shift_id", "department_id");



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_shift_area_cover_assign_key" UNIQUE ("shift_area_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."shift_defaults"
    ADD CONSTRAINT "shift_defaults_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_defaults"
    ADD CONSTRAINT "shift_defaults_shift_type_key" UNIQUE ("shift_type");



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_shift_id_porter_id_key" UNIQUE ("shift_id", "porter_id");



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_shift_id_service_id_key" UNIQUE ("shift_id", "service_id");



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter__shift_support_service_assignm_key" UNIQUE ("shift_support_service_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_staff_id_department_id_key" UNIQUE ("staff_id", "department_id");



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_service_assignments"
    ADD CONSTRAINT "support_service_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assign_support_service_assignment_id_key" UNIQUE ("support_service_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."support_services"
    ADD CONSTRAINT "support_services_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."support_services"
    ADD CONSTRAINT "support_services_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_task_item_id_department_id_key" UNIQUE ("task_item_id", "department_id");



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_task_type_id_department_id_key" UNIQUE ("task_type_id", "department_id");



ALTER TABLE ONLY "public"."task_types"
    ADD CONSTRAINT "task_types_pkey" PRIMARY KEY ("id");



CREATE INDEX "area_cover_assignments_department_id_idx" ON "public"."area_cover_assignments" USING "btree" ("department_id");



CREATE INDEX "area_cover_assignments_porter_id_idx" ON "public"."area_cover_assignments" USING "btree" ("porter_id");



CREATE INDEX "area_cover_porter_assignments_area_cover_id_idx" ON "public"."area_cover_porter_assignments" USING "btree" ("area_cover_assignment_id");



CREATE INDEX "area_cover_porter_assignments_porter_id_idx" ON "public"."area_cover_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "departments_building_id_idx" ON "public"."departments" USING "btree" ("building_id");



CREATE INDEX "shift_area_cover_assignments_department_id_idx" ON "public"."shift_area_cover_assignments" USING "btree" ("department_id");



CREATE INDEX "shift_area_cover_assignments_shift_id_idx" ON "public"."shift_area_cover_assignments" USING "btree" ("shift_id");



CREATE INDEX "shift_area_cover_porter_assignments_porter_id_idx" ON "public"."shift_area_cover_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "shift_area_cover_porter_assignments_shift_area_cover_id_idx" ON "public"."shift_area_cover_porter_assignments" USING "btree" ("shift_area_cover_assignment_id");



CREATE INDEX "shift_porter_pool_porter_id_idx" ON "public"."shift_porter_pool" USING "btree" ("porter_id");



CREATE INDEX "shift_porter_pool_shift_id_idx" ON "public"."shift_porter_pool" USING "btree" ("shift_id");



CREATE INDEX "shift_support_service_assignments_service_id_idx" ON "public"."shift_support_service_assignments" USING "btree" ("service_id");



CREATE INDEX "shift_support_service_assignments_shift_id_idx" ON "public"."shift_support_service_assignments" USING "btree" ("shift_id");



CREATE INDEX "shift_support_service_porter_assignments_assignment_id_idx" ON "public"."shift_support_service_porter_assignments" USING "btree" ("shift_support_service_assignment_id");



CREATE INDEX "shift_support_service_porter_assignments_porter_id_idx" ON "public"."shift_support_service_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "shift_tasks_destination_department_id_idx" ON "public"."shift_tasks" USING "btree" ("destination_department_id");



CREATE INDEX "shift_tasks_origin_department_id_idx" ON "public"."shift_tasks" USING "btree" ("origin_department_id");



CREATE INDEX "shift_tasks_porter_id_idx" ON "public"."shift_tasks" USING "btree" ("porter_id");



CREATE INDEX "shift_tasks_shift_id_idx" ON "public"."shift_tasks" USING "btree" ("shift_id");



CREATE INDEX "shift_tasks_status_idx" ON "public"."shift_tasks" USING "btree" ("status");



CREATE INDEX "shift_tasks_task_item_id_idx" ON "public"."shift_tasks" USING "btree" ("task_item_id");



CREATE INDEX "shifts_is_active_idx" ON "public"."shifts" USING "btree" ("is_active");



CREATE INDEX "shifts_shift_type_idx" ON "public"."shifts" USING "btree" ("shift_type");



CREATE INDEX "shifts_supervisor_id_idx" ON "public"."shifts" USING "btree" ("supervisor_id");



CREATE INDEX "staff_department_id_idx" ON "public"."staff" USING "btree" ("department_id");



CREATE INDEX "staff_dept_dept_id_idx" ON "public"."staff_department_assignments" USING "btree" ("department_id");



CREATE INDEX "staff_dept_staff_id_idx" ON "public"."staff_department_assignments" USING "btree" ("staff_id");



CREATE INDEX "staff_role_idx" ON "public"."staff" USING "btree" ("role");



CREATE INDEX "support_service_assignments_service_id_idx" ON "public"."support_service_assignments" USING "btree" ("service_id");



CREATE INDEX "support_service_porter_assignments_porter_id_idx" ON "public"."support_service_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "support_service_porter_assignments_service_id_idx" ON "public"."support_service_porter_assignments" USING "btree" ("support_service_assignment_id");



CREATE INDEX "support_services_is_active_idx" ON "public"."support_services" USING "btree" ("is_active");



CREATE INDEX "task_item_dept_assign_dept_id_idx" ON "public"."task_item_department_assignments" USING "btree" ("department_id");



CREATE INDEX "task_item_dept_assign_task_item_id_idx" ON "public"."task_item_department_assignments" USING "btree" ("task_item_id");



CREATE INDEX "task_items_task_type_id_idx" ON "public"."task_items" USING "btree" ("task_type_id");



CREATE INDEX "task_type_dept_assign_dept_id_idx" ON "public"."task_type_department_assignments" USING "btree" ("department_id");



CREATE INDEX "task_type_dept_assign_task_type_id_idx" ON "public"."task_type_department_assignments" USING "btree" ("task_type_id");



CREATE OR REPLACE TRIGGER "update_app_settings_updated_at" BEFORE UPDATE ON "public"."app_settings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_area_cover_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_area_cover_porter_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_buildings_updated_at" BEFORE UPDATE ON "public"."buildings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_departments_updated_at" BEFORE UPDATE ON "public"."departments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_porter_pool_updated_at" BEFORE UPDATE ON "public"."shift_porter_pool" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_support_service_assignments_updated_at" BEFORE UPDATE ON "public"."shift_support_service_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_support_service_porter_assignments_updated_at" BEFORE UPDATE ON "public"."shift_support_service_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_tasks_updated_at" BEFORE UPDATE ON "public"."shift_tasks" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shifts_updated_at" BEFORE UPDATE ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_staff_updated_at" BEFORE UPDATE ON "public"."staff" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_support_service_assignments_updated_at" BEFORE UPDATE ON "public"."support_service_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_support_service_porter_assignments_updated_at" BEFORE UPDATE ON "public"."support_service_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_support_services_updated_at" BEFORE UPDATE ON "public"."support_services" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_task_items_updated_at" BEFORE UPDATE ON "public"."task_items" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_task_types_updated_at" BEFORE UPDATE ON "public"."task_types" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."area_cover_assignments"
    ADD CONSTRAINT "area_cover_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."area_cover_assignments"
    ADD CONSTRAINT "area_cover_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_area_cover_assignment_id_fkey" FOREIGN KEY ("area_cover_assignment_id") REFERENCES "public"."area_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."area_cover_porter_assignments"
    ADD CONSTRAINT "area_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_building_id_fkey" FOREIGN KEY ("building_id") REFERENCES "public"."buildings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_assignments"
    ADD CONSTRAINT "shift_area_cover_assignments_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_area_cover_porter_assignments"
    ADD CONSTRAINT "shift_area_cover_porter_assignments_shift_area_cover_assig_fkey" FOREIGN KEY ("shift_area_cover_assignment_id") REFERENCES "public"."shift_area_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_porter_pool"
    ADD CONSTRAINT "shift_porter_pool_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."support_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_assignments"
    ADD CONSTRAINT "shift_support_service_assignments_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter__shift_support_service_assign_fkey" FOREIGN KEY ("shift_support_service_assignment_id") REFERENCES "public"."shift_support_service_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_support_service_porter_assignments"
    ADD CONSTRAINT "shift_support_service_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_destination_department_id_fkey" FOREIGN KEY ("destination_department_id") REFERENCES "public"."departments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_origin_department_id_fkey" FOREIGN KEY ("origin_department_id") REFERENCES "public"."departments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_tasks"
    ADD CONSTRAINT "shift_tasks_task_item_id_fkey" FOREIGN KEY ("task_item_id") REFERENCES "public"."task_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff_department_assignments"
    ADD CONSTRAINT "staff_department_assignments_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff"
    ADD CONSTRAINT "staff_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."support_service_assignments"
    ADD CONSTRAINT "support_service_assignments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."support_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assign_support_service_assignment_i_fkey" FOREIGN KEY ("support_service_assignment_id") REFERENCES "public"."support_service_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."support_service_porter_assignments"
    ADD CONSTRAINT "support_service_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_item_department_assignments"
    ADD CONSTRAINT "task_item_department_assignments_task_item_id_fkey" FOREIGN KEY ("task_item_id") REFERENCES "public"."task_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_task_type_id_fkey" FOREIGN KEY ("task_type_id") REFERENCES "public"."task_types"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_type_department_assignments"
    ADD CONSTRAINT "task_type_department_assignments_task_type_id_fkey" FOREIGN KEY ("task_type_id") REFERENCES "public"."task_types"("id") ON DELETE CASCADE;



CREATE POLICY "Allow authenticated users to manage shift defaults" ON "public"."shift_defaults" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to manage shift tasks" ON "public"."shift_tasks" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to manage shifts" ON "public"."shifts" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to read all shift defaults" ON "public"."shift_defaults" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


















GRANT ALL ON TABLE "public"."app_settings" TO "anon";
GRANT ALL ON TABLE "public"."app_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."app_settings" TO "service_role";



GRANT ALL ON TABLE "public"."area_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."area_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."area_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."area_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."area_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."area_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."buildings" TO "anon";
GRANT ALL ON TABLE "public"."buildings" TO "authenticated";
GRANT ALL ON TABLE "public"."buildings" TO "service_role";



GRANT ALL ON TABLE "public"."departments" TO "anon";
GRANT ALL ON TABLE "public"."departments" TO "authenticated";
GRANT ALL ON TABLE "public"."departments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_area_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_area_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_area_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_area_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_area_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_area_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_defaults" TO "anon";
GRANT ALL ON TABLE "public"."shift_defaults" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_defaults" TO "service_role";



GRANT ALL ON TABLE "public"."shift_porter_pool" TO "anon";
GRANT ALL ON TABLE "public"."shift_porter_pool" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_porter_pool" TO "service_role";



GRANT ALL ON TABLE "public"."shift_support_service_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_support_service_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_support_service_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_support_service_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."shift_support_service_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_support_service_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."shift_tasks" TO "anon";
GRANT ALL ON TABLE "public"."shift_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_tasks" TO "service_role";



GRANT ALL ON TABLE "public"."shift_tasks_backup" TO "anon";
GRANT ALL ON TABLE "public"."shift_tasks_backup" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_tasks_backup" TO "service_role";



GRANT ALL ON TABLE "public"."shifts" TO "anon";
GRANT ALL ON TABLE "public"."shifts" TO "authenticated";
GRANT ALL ON TABLE "public"."shifts" TO "service_role";



GRANT ALL ON TABLE "public"."staff" TO "anon";
GRANT ALL ON TABLE "public"."staff" TO "authenticated";
GRANT ALL ON TABLE "public"."staff" TO "service_role";



GRANT ALL ON TABLE "public"."staff_department_assignments" TO "anon";
GRANT ALL ON TABLE "public"."staff_department_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_department_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."support_service_assignments" TO "anon";
GRANT ALL ON TABLE "public"."support_service_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."support_service_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."support_service_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."support_service_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."support_service_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."support_services" TO "anon";
GRANT ALL ON TABLE "public"."support_services" TO "authenticated";
GRANT ALL ON TABLE "public"."support_services" TO "service_role";



GRANT ALL ON TABLE "public"."task_item_department_assignments" TO "anon";
GRANT ALL ON TABLE "public"."task_item_department_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."task_item_department_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."task_items" TO "anon";
GRANT ALL ON TABLE "public"."task_items" TO "authenticated";
GRANT ALL ON TABLE "public"."task_items" TO "service_role";



GRANT ALL ON TABLE "public"."task_type_department_assignments" TO "anon";
GRANT ALL ON TABLE "public"."task_type_department_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."task_type_department_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."task_types" TO "anon";
GRANT ALL ON TABLE "public"."task_types" TO "authenticated";
GRANT ALL ON TABLE "public"."task_types" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
SET session_replication_role = replica;

--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 15.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--



--
-- Data for Name: app_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."app_settings" ("id", "timezone", "time_format", "created_at", "updated_at") VALUES
	('d0457585-be03-44a4-a2c2-1669c6a9a7fc', 'UTC', '24h', '2025-05-24 11:53:29.67357+00', '2025-05-24 11:53:29.67357+00'),
	('76c2f394-4c47-4010-b0bd-b687398a495d', 'UTC', '12h', '2025-05-24 11:57:56.481832+00', '2025-05-24 11:57:56.215+00'),
	('63f99fa6-34e0-4ca5-b4a4-458d859d2766', 'GMT', '24h', '2025-05-24 11:58:53.469637+00', '2025-05-24 11:58:53.352+00'),
	('22639f07-209d-41e6-b3e3-f569b6c4db96', 'GMT', '24h', '2025-05-24 12:03:15.409004+00', '2025-05-24 12:03:15.198+00');


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."buildings" ("id", "name", "address", "created_at", "updated_at") VALUES
	('b4891ac9-bb9c-4c63-977d-038890607b98', 'Harstshead', NULL, '2025-05-22 10:41:06.907057+00', '2025-05-22 10:41:06.907057+00'),
	('d4d0bf79-eb71-477e-9d06-03159039e425', 'New Fountain House', NULL, '2025-05-24 12:20:27.560098+00', '2025-05-24 12:20:27.560098+00'),
	('5e80f040-98ba-4969-9e69-99149664ecac', 'Stores', NULL, '2025-05-24 12:21:43.496202+00', '2025-05-24 12:21:43.496202+00'),
	('e85c40e7-6f29-4e22-9787-6ed289c36429', 'Charlesworth Building', NULL, '2025-05-24 12:20:54.129832+00', '2025-05-24 14:01:55.535889+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ladysmith Building', '123 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-05-24 15:10:52.043497+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Werneth House', '200 Science Boulevard', '2025-05-22 10:30:30.870153+00', '2025-05-24 15:15:47.821777+00'),
	('69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Unit', NULL, '2025-05-24 15:31:30.919629+00', '2025-05-24 15:31:30.919629+00'),
	('23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Portland Building', NULL, '2025-05-24 15:33:42.930237+00', '2025-05-24 15:33:42.930237+00'),
	('e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal Unit', NULL, '2025-05-24 15:34:16.907485+00', '2025-05-24 15:34:16.907485+00'),
	('e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Bereavement Centre', NULL, '2025-05-24 15:12:37.764027+00', '2025-05-25 09:15:35.971868+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."departments" ("id", "building_id", "name", "is_frequent", "created_at", "updated_at") VALUES
	('831035d1-93e9-4683-af25-b40c2332b2fe', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'EOU', false, '2025-05-22 10:41:18.749919+00', '2025-05-22 10:41:18.749919+00'),
	('81c30d93-8712-405c-ac5e-509d48fd9af9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'AMU', true, '2025-05-23 14:37:07.660982+00', '2025-05-23 14:37:10.792334+00'),
	('2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'NICU', false, '2025-05-24 12:21:01.329031+00', '2025-05-24 12:21:01.329031+00'),
	('52c4ae93-8ede-45d9-b5ff-d5e87b4f20aa', '5e80f040-98ba-4969-9e69-99149664ecac', 'Gas Store', false, '2025-05-24 12:21:52.935222+00', '2025-05-24 12:21:52.935222+00'),
	('6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 27', false, '2025-05-24 15:04:56.615271+00', '2025-05-24 15:04:56.615271+00'),
	('fa9e4d42-8282-42f8-bfd4-87691e20c7ed', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Ward', false, '2025-05-24 15:05:14.044021+00', '2025-05-24 15:05:14.044021+00'),
	('9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 30 (HCU)', false, '2025-05-24 15:05:26.651408+00', '2025-05-24 15:05:26.651408+00'),
	('c24a3784-6a06-469f-a764-49621f2d88d3', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 31', false, '2025-05-24 15:05:37.494475+00', '2025-05-24 15:05:37.494475+00'),
	('8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'IAU', false, '2025-05-24 15:05:46.603744+00', '2025-05-24 15:05:46.603744+00'),
	('6dc82d06-d4d2-4824-9a83-d89b583b7554', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'SDEC', false, '2025-05-24 15:05:53.620867+00', '2025-05-24 15:05:53.620867+00'),
	('a8d3be01-4d46-41c1-b304-ab98610847e7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Vasular Studies', false, '2025-05-24 15:06:04.488647+00', '2025-05-24 15:06:10.489707+00'),
	('1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'A+E (ED)', false, '2025-05-24 15:06:24.428146+00', '2025-05-24 15:06:24.428146+00'),
	('f9d3bbce-8644-4075-8b80-457777f6d16c', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Ground Floor', false, '2025-05-24 15:06:39.563069+00', '2025-05-24 15:06:39.563069+00'),
	('8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Lower Ground Floor', false, '2025-05-24 15:06:52.499906+00', '2025-05-24 15:06:52.499906+00'),
	('42c2b3ab-f68d-429c-9675-3c79ff0ed222', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Ultrasound', false, '2025-05-24 15:07:04.431723+00', '2025-05-24 15:07:04.431723+00'),
	('35c73844-b511-423e-996c-5328ef21fedd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Clinics A-F', false, '2025-05-24 15:07:14.550747+00', '2025-05-24 15:07:14.550747+00'),
	('7295def1-1827-46dc-a443-a7aa7bf85b52', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Yellow Suite', false, '2025-05-24 15:07:27.863388+00', '2025-05-24 15:07:27.863388+00'),
	('f7c99832-60d1-42ee-8d35-0620a38f1e5d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Blue Suite', false, '2025-05-24 15:07:36.0704+00', '2025-05-24 15:07:36.0704+00'),
	('465893b5-6ab8-4776-bdbd-fd3c608ab966', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Swan Room', false, '2025-05-24 15:07:48.317926+00', '2025-05-24 15:07:48.317926+00'),
	('dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s Unit', false, '2025-05-24 15:08:15.838239+00', '2025-05-24 15:08:15.838239+00'),
	('ac2333d2-0b37-4924-a039-478caf702fbd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s O+A', false, '2025-05-24 15:08:31.112268+00', '2025-05-24 15:08:31.112268+00'),
	('7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Day Surgery', false, '2025-05-24 15:09:06.573728+00', '2025-05-24 15:09:06.573728+00'),
	('4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Endoscopy Unit', false, '2025-05-24 15:09:18.185641+00', '2025-05-24 15:09:18.185641+00'),
	('c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'POU', false, '2025-05-24 15:09:37.760662+00', '2025-05-24 15:09:37.760662+00'),
	('f7525622-cd84-4c8c-94bf-b0428008b9c3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Frailty', false, '2025-05-24 15:10:12.266212+00', '2025-05-24 15:10:12.266212+00'),
	('36e599c5-89b2-4d50-b7df-47d5d1959ca4', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Surgical Hub', false, '2025-05-24 15:10:26.062318+00', '2025-05-24 15:10:26.062318+00'),
	('19b02bca-1dc6-4d00-b04d-a7e141a04870', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Plaster Room', false, '2025-05-24 15:10:32.921441+00', '2025-05-24 15:10:32.921441+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 40', false, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:10:59.203581+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 41', false, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:11:06.887444+00'),
	('3aa17398-7823-45ae-b76c-9b30d8509ce1', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 42', false, '2025-05-24 15:11:16.394196+00', '2025-05-24 15:11:16.394196+00'),
	('76753b4b-ae1e-4477-a042-8deaab558e7b', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Discharge Lounge', false, '2025-05-24 15:11:40.525042+00', '2025-05-24 15:11:40.525042+00'),
	('1ae5c936-b74c-453e-a614-42b983416e40', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 43', false, '2025-05-24 15:11:49.971178+00', '2025-05-24 15:11:49.971178+00'),
	('0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 44', false, '2025-05-24 15:11:55.713923+00', '2025-05-24 15:11:55.713923+00'),
	('569e9211-d394-4e93-ba3e-34ad20d98af4', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 45', false, '2025-05-24 15:12:01.01766+00', '2025-05-24 15:12:01.01766+00'),
	('0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 46', false, '2025-05-24 15:12:07.981632+00', '2025-05-24 15:12:07.981632+00'),
	('99d8db21-2c14-4f8f-8e54-54fc81004997', 'e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Rose Cottage', false, '2025-05-24 15:12:49.940045+00', '2025-05-24 15:12:49.940045+00'),
	('87a21a43-fe29-448f-9c08-b4d94226ad3f', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Infection Control', false, '2025-05-24 15:13:12.738948+00', '2025-05-24 15:13:12.738948+00'),
	('60c6f384-09d7-4ec8-bc90-b72fe1d82af9', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Switch', false, '2025-05-24 15:13:28.133871+00', '2025-05-24 15:13:28.133871+00'),
	('c06cd3c4-8993-4e7b-b198-a7fda4ede658', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Estates Management', false, '2025-05-24 15:13:37.481503+00', '2025-05-24 15:13:55.996814+00'),
	('a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'CDS (Acorn Birth Centre)', false, '2025-05-24 15:14:21.560252+00', '2025-05-24 15:14:40.302505+00'),
	('571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Womens Health', false, '2025-05-24 15:14:53.225063+00', '2025-05-24 15:14:53.225063+00'),
	('23199491-fe75-4c33-9cc8-1c86070cf0d1', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Triage', false, '2025-05-24 15:15:20.429518+00', '2025-05-24 15:15:20.429518+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Library', false, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:15:56.37151+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d488', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Lecture Theatre', true, '2025-05-22 10:30:30.870153+00', '2025-05-24 15:16:06.796323+00'),
	('c0a07de6-b201-441b-a1fb-2b2ae9a95ac1', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Reception', false, '2025-05-24 15:16:21.942089+00', '2025-05-24 15:16:21.942089+00'),
	('bcb9ab4c-88c9-4d90-8b10-d97216de49ed', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Transfusion', false, '2025-05-24 15:20:33.127806+00', '2025-05-24 15:20:33.127806+00'),
	('9056ee14-242b-4208-a87d-fc59d24d442c', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Pathology Lab', false, '2025-05-24 12:20:41.049859+00', '2025-05-24 15:20:39.255686+00'),
	('969a27a7-f5e5-4c23-b018-128aa2000b97', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Bed Store', false, '2025-05-24 15:21:21.166917+00', '2025-05-24 15:21:21.166917+00'),
	('5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Mattress Store', false, '2025-05-24 15:21:31.144781+00', '2025-05-24 15:21:31.144781+00'),
	('9dae2f86-2058-4c9c-a428-76f5648553d3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'North Theatres', false, '2025-05-24 15:24:43.214387+00', '2025-05-24 15:24:43.214387+00'),
	('07e2b454-88ee-4d6a-9d75-a6ffa39bd241', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'South Theatres', false, '2025-05-24 15:24:51.854136+00', '2025-05-24 15:24:51.854136+00'),
	('5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'CT Scanner', false, '2025-05-24 15:25:11.218374+00', '2025-05-24 15:25:11.218374+00'),
	('d82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'MRI', false, '2025-05-24 15:25:16.973586+00', '2025-05-24 15:25:16.973586+00'),
	('df3d8d2a-dee5-4a21-a362-401236a2a1cb', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Pharmacy', false, '2025-05-24 15:30:28.871857+00', '2025-05-24 15:30:28.871857+00'),
	('943915e4-6818-4890-b395-a8272718eaf7', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford One', false, '2025-05-24 15:31:43.707094+00', '2025-05-24 15:31:43.707094+00'),
	('0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Two', false, '2025-05-24 15:31:53.020936+00', '2025-05-24 15:31:53.020936+00'),
	('1cac53b0-f370-4a13-95ca-f4cfd85dd197', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Ground', false, '2025-05-24 15:32:00.795352+00', '2025-05-24 15:32:00.795352+00'),
	('55f54692-d1ee-4047-bace-ff31744d2bc7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'FM Corridor', false, '2025-05-24 15:32:36.1272+00', '2025-05-24 15:32:36.1272+00'),
	('270df887-a13f-4004-a58d-9cec125b8da1', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Kitchens', false, '2025-05-24 15:32:43.567186+00', '2025-05-24 15:32:43.567186+00'),
	('06582332-0637-4d1a-b86e-876afe0bdc98', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Laundry', false, '2025-05-24 15:33:51.477397+00', '2025-05-24 15:33:51.477397+00'),
	('bf03ffcf-98d7-440e-adc1-5081e161c42d', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'I.T.', false, '2025-05-24 15:33:57.806509+00', '2025-05-24 15:33:57.806509+00'),
	('2368699a-6de0-45a9-ae25-dad26160cada', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Porters Lodge', false, '2025-05-24 15:34:07.683358+00', '2025-05-24 15:34:07.683358+00'),
	('ccb6bf8f-275c-4d24-8907-09b97cbe0eea', 'e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal', false, '2025-05-24 15:34:28.590837+00', '2025-05-24 15:34:28.590837+00');


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."staff" ("id", "first_name", "last_name", "role", "created_at", "updated_at", "department_id") VALUES
	('75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'Porter', 'Three', 'porter', '2025-05-22 15:14:47.797324+00', '2025-05-22 15:14:47.797324+00', NULL),
	('4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'Martin', 'Smith', 'supervisor', '2025-05-22 16:38:43.142566+00', '2025-05-22 16:38:43.142566+00', NULL),
	('b88b49d1-c394-491e-aaa7-cc196250f0e4', 'Martin', 'Fearon', 'supervisor', '2025-05-22 12:36:39.488519+00', '2025-05-22 16:38:53.581199+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484'),
	('358aa759-e11e-40b0-b886-37481c5eb6c0', 'Chris', 'Chrombie', 'supervisor', '2025-05-22 16:39:03.319212+00', '2025-05-22 16:39:03.319212+00', NULL),
	('a9d969e3-d449-4005-a679-f63be07c6872', 'Luke', 'Clements', 'supervisor', '2025-05-22 16:39:16.282662+00', '2025-05-22 16:39:16.282662+00', NULL),
	('786d6d23-69b9-433e-92ed-938806cb10a8', 'Porter', 'Four', 'porter', '2025-05-23 14:15:42.030594+00', '2025-05-23 14:15:42.030594+00', NULL),
	('2e74429e-2aab-4bed-a979-6ccbdef74596', 'Porter', 'Six', 'porter', '2025-05-24 15:27:50.974195+00', '2025-05-24 15:27:50.974195+00', NULL),
	('ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', 'Porter', 'Seven', 'porter', '2025-05-24 15:28:02.842334+00', '2025-05-24 15:28:02.842334+00', NULL),
	('78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', 'Porter', 'Eight', 'porter', '2025-05-24 15:28:08.999647+00', '2025-05-24 15:28:08.999647+00', NULL),
	('bf79faf6-fb3e-4780-841e-63a4a67a5b77', 'Porter', 'Nine', 'porter', '2025-05-24 15:28:15.192437+00', '2025-05-24 15:28:15.192437+00', NULL),
	('8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'Porter', 'Ten', 'porter', '2025-05-24 15:28:21.287841+00', '2025-05-24 15:28:21.287841+00', NULL),
	('7c20aec3-bf78-4ef9-b35e-429e41ac739b', 'Porter', 'Eleven', 'porter', '2025-05-24 15:28:35.013201+00', '2025-05-24 15:28:35.013201+00', NULL),
	('ecc67de0-fecc-4c93-b9da-445c3cef4ea4', 'Porter', 'Twelve', 'porter', '2025-05-24 15:28:41.635621+00', '2025-05-24 15:28:41.635621+00', NULL),
	('2524b1c5-45e1-4f15-bf3b-984354f22cdc', 'Porter', 'Thirteen', 'porter', '2025-05-24 15:28:50.433536+00', '2025-05-24 15:28:50.433536+00', NULL),
	('f304fa99-8e00-48d0-a616-d156b0f7484d', 'Porter', 'Fourteen', 'porter', '2025-05-24 15:29:00.080381+00', '2025-05-24 15:29:00.080381+00', NULL),
	('4fb21c6f-2f5b-4f6e-b727-239a3391092a', 'Porter', 'Fifteen', 'porter', '2025-05-24 15:29:10.541023+00', '2025-05-24 15:29:10.541023+00', NULL),
	('394d8660-7946-4b31-87c9-b60f7e1bc294', 'Porter', 'Five', 'porter', '2025-05-23 14:36:44.275665+00', '2025-05-24 15:29:23.335292+00', NULL),
	('12055968-78d3-4404-a05f-10e039217936', 'Porter', 'One', 'porter', '2025-05-24 15:35:19.897285+00', '2025-05-24 15:35:19.897285+00', NULL),
	('8b3b3e97-ea54-4c40-884b-04d3d24dbe23', 'Porter', 'Sixteen', 'porter', '2025-05-24 15:46:43.723804+00', '2025-05-24 15:46:43.723804+00', NULL),
	('8eaa9194-b164-4cb4-a15c-956299ff28c5', 'Porter', 'Seventeen', 'porter', '2025-05-24 15:46:56.110419+00', '2025-05-24 15:46:56.110419+00', NULL),
	('e55b1013-7e79-4e38-913e-c53de591f85c', 'Porter', 'Eighteen', 'porter', '2025-05-24 15:47:03.70938+00', '2025-05-24 15:47:03.70938+00', NULL),
	('4e87f01b-5196-47c4-b424-4cfdbe7fb385', 'Porter', 'Nineteen', 'porter', '2025-05-24 15:47:12.658077+00', '2025-05-24 15:47:12.658077+00', NULL),
	('69766d05-49d7-4e7c-8734-e3dc8949bf91', 'Porter', 'Twenty', 'porter', '2025-05-24 15:47:22.720752+00', '2025-05-24 15:47:22.720752+00', NULL),
	('ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'Porter', 'Two', 'porter', '2025-05-22 15:14:27.136064+00', '2025-05-25 09:56:14.035659+00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a');


--
-- Data for Name: area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_assignments" ("id", "department_id", "porter_id", "start_time", "end_time", "color", "created_at", "updated_at", "shift_type") VALUES
	('a2787626-bc01-411b-a2ca-a50d2c63ced6', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '08:00:00', '20:00:00', '#4285F4', '2025-05-24 15:30:45.762708+00', '2025-05-24 15:37:35.40178+00', 'week_day'),
	('c3c5f876-957f-4c82-98ef-0f1ab17ed640', '81c30d93-8712-405c-ac5e-509d48fd9af9', NULL, '11:00:00', '18:00:00', '#4285F4', '2025-05-24 15:30:53.446376+00', '2025-05-24 15:38:28.471112+00', 'week_day'),
	('8c7bca61-81c3-4fa9-a259-fa780b55471f', 'df3d8d2a-dee5-4a21-a362-401236a2a1cb', NULL, '07:00:00', '18:30:00', '#4285F4', '2025-05-24 15:31:03.287986+00', '2025-05-24 15:40:22.116165+00', 'week_day'),
	('fec7a8ae-9f68-4623-8454-bc0c3ad361b7', 'f9d3bbce-8644-4075-8b80-457777f6d16c', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:40:43.644087+00', '2025-05-24 15:40:43.644087+00', 'week_day'),
	('4030ddba-717e-498d-92fc-cf401ef4d908', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:40:52.51208+00', '2025-05-24 15:40:52.51208+00', 'week_day'),
	('089d9780-7c76-4a90-90fc-38bb51296b99', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:41:06.887434+00', '2025-05-24 15:41:06.887434+00', 'week_day'),
	('1d4a326e-8401-4e31-b1ec-fa810b68fd1a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '20:00:00', '08:00:00', '#4285F4', '2025-05-24 15:42:29.23697+00', '2025-05-24 15:43:46.486541+00', 'week_night'),
	('2100396b-f96d-4a7c-9d1b-006775df4ef7', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:44:23.448158+00', '2025-05-24 15:44:43.398907+00', 'weekend_night'),
	('06213b7c-812e-4f48-a79d-ecbc9a87d30a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '08:00:00', '20:00:00', '#4285F4', '2025-05-24 15:45:03.686512+00', '2025-05-24 15:45:40.587037+00', 'weekend_day'),
	('8c1d80d9-68f3-4bc2-a578-5707de26e00f', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-25 09:56:41.356955+00', '2025-05-25 09:56:41.356955+00', 'week_night');


--
-- Data for Name: area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_porter_assignments" ("id", "area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('8faa39c0-2e97-49f5-b3f3-cfac21a62a07', 'a2787626-bc01-411b-a2ca-a50d2c63ced6', '12055968-78d3-4404-a05f-10e039217936', '06:00:00', '14:00:00', '2025-05-24 15:37:35.492755+00', '2025-05-24 15:37:35.492755+00'),
	('e4c07ff1-64c6-4c07-8da2-3ba9112a599b', 'a2787626-bc01-411b-a2ca-a50d2c63ced6', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '09:00:00', '17:00:00', '2025-05-24 15:37:35.56537+00', '2025-05-24 15:37:35.56537+00'),
	('60466424-d660-40a8-8d7f-ad1c3bf3000f', 'a2787626-bc01-411b-a2ca-a50d2c63ced6', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '14:00:00', '22:00:00', '2025-05-24 15:37:35.634775+00', '2025-05-24 15:37:35.634775+00'),
	('c59ce969-2868-41f3-af34-dd5ad7d68db0', 'c3c5f876-957f-4c82-98ef-0f1ab17ed640', '786d6d23-69b9-433e-92ed-938806cb10a8', '11:00:00', '18:00:00', '2025-05-24 15:38:28.555892+00', '2025-05-24 15:38:28.555892+00'),
	('27f67fa6-0ae5-4142-a4cc-9a643283d908', '8c7bca61-81c3-4fa9-a259-fa780b55471f', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '07:00:00', '15:00:00', '2025-05-24 15:40:22.184915+00', '2025-05-24 15:40:22.184915+00'),
	('39c6abb8-0a5b-4e08-a992-d03c337eec96', '8c7bca61-81c3-4fa9-a259-fa780b55471f', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '15:00:00', '18:30:00', '2025-05-24 15:40:22.278146+00', '2025-05-24 15:40:22.278146+00'),
	('f6aad801-364c-43fb-a26e-4f05c1fed813', '1d4a326e-8401-4e31-b1ec-fa810b68fd1a', '2e74429e-2aab-4bed-a979-6ccbdef74596', '20:00:00', '08:00:00', '2025-05-24 15:43:46.55611+00', '2025-05-24 15:43:46.55611+00'),
	('8aa2abd0-2367-4238-a331-cea351b1b5eb', '2100396b-f96d-4a7c-9d1b-006775df4ef7', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '20:00:00', '08:00:00', '2025-05-24 15:44:43.562482+00', '2025-05-24 15:44:43.562482+00'),
	('692ea937-c08b-4913-91e3-a5b2aa5e13ae', '06213b7c-812e-4f48-a79d-ecbc9a87d30a', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '20:00:00', '2025-05-24 15:45:40.664042+00', '2025-05-24 15:45:40.664042+00');


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shifts" ("id", "supervisor_id", "shift_type", "start_time", "end_time", "is_active", "created_at", "updated_at") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d491', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'night', '2025-05-23 05:24:46.89275+00', '2025-05-23 14:15:54.406+00', false, '2025-05-23 08:24:46.89275+00', '2025-05-23 14:15:54.724487+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d490', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'day', '2025-05-23 06:24:46.89275+00', '2025-05-23 14:15:59.682+00', false, '2025-05-23 08:24:46.89275+00', '2025-05-23 14:16:00.001677+00'),
	('eca831e9-fa9f-4604-9526-0a6f70040f86', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'day', '2025-05-23 08:47:36.33+00', '2025-05-23 14:16:03.596+00', false, '2025-05-23 08:47:36.411612+00', '2025-05-23 14:16:03.931319+00'),
	('17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'a9d969e3-d449-4005-a679-f63be07c6872', 'night', '2025-05-23 13:17:58.966+00', '2025-05-23 14:16:51.017+00', false, '2025-05-23 13:17:59.136287+00', '2025-05-23 14:16:51.36234+00'),
	('f9f8c607-d370-4ed8-94f0-dcee9f9be460', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'day', '2025-05-25 11:21:45.9+00', NULL, true, '2025-05-25 11:21:45.975115+00', '2025-05-25 11:21:45.975115+00');


--
-- Data for Name: shift_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_assignments" ("id", "shift_id", "department_id", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('0c72ef0b-5e3b-421b-8e13-2f84ef1d2ef2', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('ed5f6696-e09e-442a-b5d2-93df694b30c0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('1f62f634-3e63-4004-ac08-c955b9b135ff', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', '831035d1-93e9-4683-af25-b40c2332b2fe', '22:00:00', '06:00:00', '#34A853', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('7c495d1b-cfc1-4f79-87df-f11dd0e828c5', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('84aacfe3-2fae-4969-9b30-b21501a35384', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('b2ad2268-c8c5-4680-a679-d86a0af9d6b3', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00'),
	('b767566b-5d75-4ccb-86ae-0efef2a4dd16', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00');


--
-- Data for Name: shift_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: shift_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_defaults" ("id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('85cc4d8d-f0fc-477a-b138-56efdcbfcdf1', 'week_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('01373b67-60e9-4422-a1ae-a8e72d119014', 'week_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('2b13f0ba-98fc-4013-9953-0da1418e8ea0', 'weekend_day', '08:00:00', '16:00:00', '#34A853', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('524485d0-141a-4574-808b-93410f62ca94', 'weekend_night', '20:00:00', '08:00:00', '#EA4335', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('f6a391c3-2e65-4b33-ad43-76857a81aa4d', 'night', '20:00:00', '08:00:00', '#5b67c8', '2025-05-22 16:22:03.801345+00', '2025-05-25 05:38:19.197+00'),
	('8472931e-f2fd-4827-a444-ab4827e706d2', 'day', '08:00:00', '20:00:00', '#3cb8e2', '2025-05-22 16:22:03.801345+00', '2025-05-25 05:38:19.197+00');


--
-- Data for Name: shift_porter_pool; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: support_services; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_services" ("id", "name", "description", "is_active", "created_at", "updated_at") VALUES
	('30c5c045-a442-4ec8-b285-c7bc010f4d83', 'Laundry', 'Porter support for laundry services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ce940139-6ae7-49de-a62a-0d6ba9397928', 'Post', 'Internal mail and document delivery', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('0b5c7062-1285-4427-8387-b1b4e14eedc9', 'Pharmacy', 'Medication delivery service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'District Drivers', 'External transport services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('7cfa1ddf-61b0-489e-ad23-b924cf995419', 'Adhoc', 'Miscellaneous tasks requiring porter assistance', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('26c0891b-56c0-4346-8d53-de906aaa64c2', 'Medical Records', 'Patient records transport service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00');


--
-- Data for Name: shift_support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: shift_support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: task_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_types" ("id", "name", "description", "created_at", "updated_at") VALUES
	('bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Equipment Transfer', 'Tasks related to moving equipment between departments', '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('b864ed57-5547-404e-9459-1641a030974e', 'Asset Delivery', NULL, '2025-05-22 11:24:42.733351+00', '2025-05-22 11:24:42.733351+00'),
	('a97d8a74-0e16-4e1f-908e-96e935d91002', 'Gases', NULL, '2025-05-22 11:24:51.97167+00', '2025-05-24 15:17:57.977482+00'),
	('f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Patient Transfer', 'Tasks related to moving patients between departments', '2025-05-22 11:12:54.89695+00', '2025-05-24 15:19:11.095037+00'),
	('fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Samples', 'Tasks related to delivering specimens to labs', '2025-05-22 11:12:54.89695+00', '2025-05-24 15:19:25.231715+00'),
	('9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Transfusion', NULL, '2025-05-24 15:23:22.494506+00', '2025-05-24 15:23:22.494506+00'),
	('e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Asset Removal', NULL, '2025-05-24 15:26:50.239275+00', '2025-05-24 15:26:50.239275+00');


--
-- Data for Name: task_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_items" ("id", "task_type_id", "name", "description", "created_at", "updated_at") VALUES
	('e6068d5d-4bc5-4358-8bae-ed23759dc733', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen F Size', NULL, '2025-05-22 11:25:09.159861+00', '2025-05-22 11:25:09.159861+00'),
	('8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed (Complete)', NULL, '2025-05-22 12:00:44.450407+00', '2025-05-22 12:00:44.450407+00'),
	('a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed Frame', NULL, '2025-05-22 12:00:52.076144+00', '2025-05-22 12:00:52.076144+00'),
	('93150478-e3b7-4315-bfb2-8f44a78b2f77', 'b864ed57-5547-404e-9459-1641a030974e', 'Mattress', NULL, '2025-05-24 15:17:23.893487+00', '2025-05-24 15:17:23.893487+00'),
	('532b14f0-042a-4ddf-bc7d-cb95ff298132', 'bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Incubator', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:17:40.681145+00'),
	('5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen E Size', NULL, '2025-05-24 15:18:10.625096+00', '2025-05-24 15:18:10.625096+00'),
	('f18bf0ce-835e-4d9d-92d0-119222a56f5e', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen D Size', NULL, '2025-05-24 15:18:21.251002+00', '2025-05-24 15:18:21.251002+00'),
	('377506db-7bf7-44e8-bc8f-c7c316914579', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Entenox E Size', NULL, '2025-05-24 15:18:39.13243+00', '2025-05-24 15:18:39.13243+00'),
	('14446938-25cd-4655-ad84-dbb7db871f28', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Bed', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:50.766252+00'),
	('68e8e006-79dc-4d5f-aed0-20755d53403b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Wheelchair', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:56.015534+00'),
	('5c269ddd-7abd-4d10-a0b3-d93fccb4f6de', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Trolly', NULL, '2025-05-24 15:19:02.302787+00', '2025-05-24 15:19:02.302787+00'),
	('dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Blood Sample', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:19:31.625374+00'),
	('934256c2-fbe5-480b-a0ac-897d9d5b9358', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Urine Sample', NULL, '2025-05-24 15:19:41.366895+00', '2025-05-24 15:19:41.366895+00'),
	('5c0c9e25-ae34-4872-8696-4c4ce6e76112', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Multiple Samples', NULL, '2025-05-24 15:19:53.083235+00', '2025-05-24 15:19:53.083235+00'),
	('e5e84800-eb11-4889-bb97-39ea75ef5190', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Blood', NULL, '2025-05-24 15:23:49.29882+00', '2025-05-24 15:23:49.29882+00'),
	('ee6c4e53-bcfa-4271-b0d5-dc61a5d0427c', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Albumen', NULL, '2025-05-24 15:23:58.062632+00', '2025-05-24 15:23:58.062632+00'),
	('b55609c2-9be4-4851-ad2c-dfc199795298', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Platelets', NULL, '2025-05-24 15:24:05.948941+00', '2025-05-24 15:24:05.948941+00'),
	('b8fed973-ab36-4d31-801a-7ebbde95413a', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed (Complete)', NULL, '2025-05-24 15:27:01.862194+00', '2025-05-24 15:27:01.862194+00'),
	('81e0d17c-740a-4a00-9727-81d222f96234', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed Frame', NULL, '2025-05-24 15:27:10.580403+00', '2025-05-24 15:27:10.580403+00'),
	('deab62e1-ae79-4f77-ab65-0a04c1f040a1', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Mattress', NULL, '2025-05-24 15:27:17.680461+00', '2025-05-24 15:27:17.680461+00'),
	('1933a5d4-e02d-4301-b580-a0fdbdbfb21d', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Walk', NULL, '2025-05-25 09:51:59.07475+00', '2025-05-25 09:51:59.07475+00');


--
-- Data for Name: shift_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('37ef35c9-6670-494d-871a-8eb16248720e', 'eca831e9-fa9f-4604-9526-0a6f70040f86', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'pending', '2025-05-23 08:49:55.479887+00', '2025-05-24 14:10:28.733507+00', '07:33', '07:34', '07:53'),
	('5e939454-7477-43e5-b5f3-65675d3e0ec7', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', NULL, '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-23 06:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('a5638fbf-2bfe-4805-be92-13d3bdab7be0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-23 08:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('8f16befe-a495-4b05-840d-cc077a569ad3', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', NULL, 'completed', '2025-05-23 09:21:47.358281+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('724f2648-0b08-41a6-8321-91619e0dbabb', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '14446938-25cd-4655-ad84-dbb7db871f28', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', NULL, 'completed', '2025-05-23 07:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53'),
	('6e25558d-f989-49ce-8d40-c5b69f1af256', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', NULL, NULL, 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-24 15:04:39.590487+00', '07:33', '07:34', '07:53');


--
-- Data for Name: shift_tasks_backup; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks_backup" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('724f2648-0b08-41a6-8321-91619e0dbabb', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '14446938-25cd-4655-ad84-dbb7db871f28', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'completed', '2025-05-23 07:24:46.89275+00', '2025-05-23 08:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('5e939454-7477-43e5-b5f3-65675d3e0ec7', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-23 06:24:46.89275+00', '2025-05-23 08:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('919ef224-d90e-4aac-8e52-dfa25ada730a', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', '0c90fbec-5d4c-46c0-b7dd-47fba327e3ed', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('0e7dce68-352e-413a-a061-20fb11aa1ab0', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'f45a46c3-2240-462f-9895-494965ecd1a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-22 08:24:46.89275+00', '2025-05-22 09:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('4a06494e-1051-4006-b130-d72b4a6eebf1', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '516e8952-a09b-456b-926d-e78411490a6d', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-22 08:24:46.89275+00', '2025-05-22 10:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('74f81abd-0b5b-465d-a979-fa6dce4c276d', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '14446938-25cd-4655-ad84-dbb7db871f28', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'pending', '2025-05-22 12:24:46.89275+00', '2025-05-22 12:24:46.89275+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('37ef35c9-6670-494d-871a-8eb16248720e', 'eca831e9-fa9f-4604-9526-0a6f70040f86', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'f45a46c3-2240-462f-9895-494965ecd1a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'pending', '2025-05-23 08:49:55.479887+00', '2025-05-23 08:50:01.281131+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('a5638fbf-2bfe-4805-be92-13d3bdab7be0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:54:22.695648+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('6e25558d-f989-49ce-8d40-c5b69f1af256', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:55:02.635556+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('8f16befe-a495-4b05-840d-cc077a569ad3', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-23 09:21:47.358281+00', '2025-05-23 09:21:47.358281+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('b57eb494-5648-4d1d-b783-aa48eced023a', 'e57acaf6-f171-42c5-958d-24ac48479180', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-23 14:35:11.683807+00', '2025-05-23 14:35:22.324033+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('1b91132f-6967-47a1-9b13-7d020244f6e6', 'e57acaf6-f171-42c5-958d-24ac48479180', '0c90fbec-5d4c-46c0-b7dd-47fba327e3ed', '786d6d23-69b9-433e-92ed-938806cb10a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-23 14:38:42.170724+00', '2025-05-23 14:38:50.047597+00', '2025-05-24 07:33:36.53481+00', '2025-05-24 07:34:36.53481+00', '2025-05-24 07:53:36.53481+00'),
	('ded0260e-9b51-4554-beb0-70e6bdf39b32', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'f45a46c3-2240-462f-9895-494965ecd1a8', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-24 07:41:55.150134+00', '2025-05-24 07:41:55.150134+00', '2025-05-24 07:41:55.025+00', '2025-05-24 07:42:55.025+00', '2025-05-24 08:01:55.025+00'),
	('9f9e0389-b2cb-4a87-a05b-b70c31459283', 'a124a872-d2d7-4324-b88a-780f82796906', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-24 08:26:33.109324+00', '2025-05-24 08:26:33.109324+00', '2025-05-24 08:26:33.044+00', '2025-05-24 08:27:33.044+00', '2025-05-24 08:46:33.044+00'),
	('591b8b57-fce6-4b8e-922e-1252774f6039', 'a124a872-d2d7-4324-b88a-780f82796906', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-24 08:31:54.281264+00', '2025-05-24 08:31:54.281264+00', '2025-05-24 08:31:54.241+00', '2025-05-24 08:32:54.241+00', '2025-05-24 08:51:54.241+00'),
	('9557e947-094b-42c3-ab99-4078c02672f6', 'a124a872-d2d7-4324-b88a-780f82796906', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'completed', '2025-05-24 11:38:53.866848+00', '2025-05-24 11:38:53.866848+00', '2025-05-24 11:38:53.786+00', '2025-05-24 11:39:53.786+00', '2025-05-24 11:58:53.786+00'),
	('b2240b4c-9d10-48f3-b7e8-97972bed7ca5', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '786d6d23-69b9-433e-92ed-938806cb10a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-24 11:40:04.592475+00', '2025-05-24 11:40:04.592475+00', '2025-05-24 11:40:04.499+00', '2025-05-24 11:41:04.499+00', '2025-05-24 12:00:04.499+00'),
	('d369e166-cdd0-4dd0-a4c1-8b3966b36cbc', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', '532b14f0-042a-4ddf-bc7d-cb95ff298132', '786d6d23-69b9-433e-92ed-938806cb10a8', '831035d1-93e9-4683-af25-b40c2332b2fe', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'completed', '2025-05-24 11:44:41.776885+00', '2025-05-24 11:44:41.776885+00', '2025-05-24 12:44:00+00', '2025-05-24 12:45:00+00', '2025-05-24 13:04:00+00'),
	('888222cb-1712-48dc-8b83-ae7cf10be5f1', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', 'e6068d5d-4bc5-4358-8bae-ed23759dc733', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-24 11:46:19.958128+00', '2025-05-24 11:46:19.958128+00', '2025-05-24 12:46:00+00', '2025-05-24 12:47:00+00', '2025-05-24 13:06:00+00'),
	('81a498e7-d3a2-40f7-8b98-1dd90d9d3a94', 'caad639d-cb8f-4fbe-a791-bdfdb2828abd', '14446938-25cd-4655-ad84-dbb7db871f28', '786d6d23-69b9-433e-92ed-938806cb10a8', '8c80c97d-010e-455e-bd7f-68dfccc27043', '831035d1-93e9-4683-af25-b40c2332b2fe', 'pending', '2025-05-24 11:59:45.542291+00', '2025-05-24 11:59:45.542291+00', '2025-05-24 12:59:00+00', '2025-05-24 13:00:00+00', '2025-05-24 13:19:00+00'),
	('6c5c9af5-1445-4da6-8786-b9672940cf9b', '0a0e958b-fe1a-4b28-96ba-cead157a49e5', '14446938-25cd-4655-ad84-dbb7db871f28', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-24 12:01:54.700136+00', '2025-05-24 12:01:54.700136+00', '2025-05-24 13:01:00+00', '2025-05-24 13:02:00+00', '2025-05-24 13:21:00+00'),
	('58b9596f-48ab-464b-99c4-755bbd3b8b76', '0a0e958b-fe1a-4b28-96ba-cead157a49e5', 'e6068d5d-4bc5-4358-8bae-ed23759dc733', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-24 12:03:36.890857+00', '2025-05-24 12:03:36.890857+00', '2025-05-24 13:03:00+00', '2025-05-24 13:04:00+00', '2025-05-24 13:23:00+00');


--
-- Data for Name: staff_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_service_assignments" ("id", "service_id", "start_time", "end_time", "color", "created_at", "updated_at", "shift_type") VALUES
	('be438b48-ecae-48ac-a9ff-b63a7f45a061', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_day'),
	('e3eab35f-e5b5-4001-a8f5-733314f7587e', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_day'),
	('1d48c9d1-e14e-4e61-a26f-24397f874980', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#FBBC05', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_day'),
	('e4a761cc-ad70-4925-8295-35c3fec29cc4', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_night'),
	('f864cc63-5b10-4679-8355-1c1bde5ffda0', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '20:00:00', '04:00:00', '#FBBC05', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_night'),
	('56356547-809d-4c8f-9bbd-bd78398d1d7a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_day'),
	('a8445e2f-ded7-45dd-a696-6b5b257764ad', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_day'),
	('2c67f62c-5bf4-4805-9ac3-e5e5a451bd85', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_night'),
	('f9596013-1567-4c31-ae8e-ebb8737e0802', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_night'),
	('fe1bac4b-c18e-49b8-bdec-d30b021d548f', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '20:00:00', '#4285F4', '2025-05-25 08:42:33.868676+00', '2025-05-25 08:42:33.868676+00', 'week_day');


--
-- Data for Name: support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_service_porter_assignments" ("id", "support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('9f3f4498-fb40-43f0-9e74-378254b94049', 'be438b48-ecae-48ac-a9ff-b63a7f45a061', '12055968-78d3-4404-a05f-10e039217936', '08:00:00', '16:00:00', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('96a6ade7-9968-49db-b70e-ccc213a9ea85', 'e3eab35f-e5b5-4001-a8f5-733314f7587e', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '08:00:00', '16:00:00', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ab4496a1-cae5-4950-970f-76c54bd8a2be', '1d48c9d1-e14e-4e61-a26f-24397f874980', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '09:00:00', '17:00:00', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00');


--
-- Data for Name: task_item_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_item_department_assignments" ("id", "task_item_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('ca6ab4d5-30dc-4cc9-8430-d5869da60a2d', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', true, false, '2025-05-24 15:21:51.189039+00'),
	('0d5d2df0-cc4d-4a68-829a-53fa3304c1e5', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', '969a27a7-f5e5-4c23-b018-128aa2000b97', true, false, '2025-05-24 15:22:08.265118+00'),
	('b081b8d8-27e2-4538-9d83-b1512f9f77ff', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', true, false, '2025-05-24 15:25:45.227716+00'),
	('33dc4387-f8a6-4e35-ae5d-303c806a7a71', '5c0c9e25-ae34-4872-8696-4c4ce6e76112', '571553c2-9f8f-4ec0-92ca-5c84f0379d0c', true, false, '2025-05-24 15:26:02.940817+00');


--
-- Data for Name: task_type_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_type_department_assignments" ("id", "task_type_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('067489a9-2cde-4791-a414-c4120ed0b08c', 'a97d8a74-0e16-4e1f-908e-96e935d91002', '52c4ae93-8ede-45d9-b5ff-d5e87b4f20aa', true, false, '2025-05-24 12:22:10.65484+00'),
	('ceaa8539-8fd6-4954-8c00-2f8aea4bb3a6', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '9056ee14-242b-4208-a87d-fc59d24d442c', false, true, '2025-05-24 12:33:59.810318+00'),
	('bfda15f6-809b-436f-abd2-d2c16dd7663c', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '81c30d93-8712-405c-ac5e-509d48fd9af9', true, false, '2025-05-24 15:22:58.114521+00'),
	('100f3cf6-3d37-4e48-90f3-c01b7874856b', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', true, false, '2025-05-24 15:23:36.64394+00');


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: supabase_storage_admin
--



--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: supabase_auth_admin
--

SELECT pg_catalog.setval('"auth"."refresh_tokens_id_seq"', 1, false);


--
-- PostgreSQL database dump complete
--

RESET ALL;
