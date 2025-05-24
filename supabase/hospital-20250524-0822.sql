

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
    CONSTRAINT "shift_tasks_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."shift_tasks" OWNER TO "postgres";


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



CREATE INDEX "task_item_dept_assign_dept_id_idx" ON "public"."task_item_department_assignments" USING "btree" ("department_id");



CREATE INDEX "task_item_dept_assign_task_item_id_idx" ON "public"."task_item_department_assignments" USING "btree" ("task_item_id");



CREATE INDEX "task_items_task_type_id_idx" ON "public"."task_items" USING "btree" ("task_type_id");



CREATE INDEX "task_type_dept_assign_dept_id_idx" ON "public"."task_type_department_assignments" USING "btree" ("department_id");



CREATE INDEX "task_type_dept_assign_task_type_id_idx" ON "public"."task_type_department_assignments" USING "btree" ("task_type_id");



CREATE OR REPLACE TRIGGER "update_area_cover_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_area_cover_porter_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_buildings_updated_at" BEFORE UPDATE ON "public"."buildings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_departments_updated_at" BEFORE UPDATE ON "public"."departments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_porter_pool_updated_at" BEFORE UPDATE ON "public"."shift_porter_pool" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shift_tasks_updated_at" BEFORE UPDATE ON "public"."shift_tasks" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_shifts_updated_at" BEFORE UPDATE ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_staff_updated_at" BEFORE UPDATE ON "public"."staff" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



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



GRANT ALL ON TABLE "public"."shift_tasks" TO "anon";
GRANT ALL ON TABLE "public"."shift_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_tasks" TO "service_role";



GRANT ALL ON TABLE "public"."shifts" TO "anon";
GRANT ALL ON TABLE "public"."shifts" TO "authenticated";
GRANT ALL ON TABLE "public"."shifts" TO "service_role";



GRANT ALL ON TABLE "public"."staff" TO "anon";
GRANT ALL ON TABLE "public"."staff" TO "authenticated";
GRANT ALL ON TABLE "public"."staff" TO "service_role";



GRANT ALL ON TABLE "public"."staff_department_assignments" TO "anon";
GRANT ALL ON TABLE "public"."staff_department_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_department_assignments" TO "service_role";



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
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."buildings" ("id", "name", "address", "created_at", "updated_at") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Main Hospital', '123 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-05-22 10:30:30.870153+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Research Center', '200 Science Boulevard', '2025-05-22 10:30:30.870153+00', '2025-05-22 10:30:30.870153+00'),
	('b4891ac9-bb9c-4c63-977d-038890607b98', 'Harstshead', NULL, '2025-05-22 10:41:06.907057+00', '2025-05-22 10:41:06.907057+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d480', 'East Wingssss', '125 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-05-22 17:32:44.747658+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."departments" ("id", "building_id", "name", "is_frequent", "created_at", "updated_at") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Radiology', false, '2025-05-22 10:30:30.870153+00', '2025-05-22 10:30:30.870153+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d486', 'f47ac10b-58cc-4372-a567-0e02b2c3d480', 'Neurology', false, '2025-05-22 10:30:30.870153+00', '2025-05-22 10:30:30.870153+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Clinical Trials', false, '2025-05-22 10:30:30.870153+00', '2025-05-22 10:30:30.870153+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d488', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Laboratories', true, '2025-05-22 10:30:30.870153+00', '2025-05-22 10:30:30.870153+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'ICU', false, '2025-05-22 10:30:30.870153+00', '2025-05-22 10:35:49.358083+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d480', 'Cardiologyies', false, '2025-05-22 10:30:30.870153+00', '2025-05-22 10:40:47.84454+00'),
	('831035d1-93e9-4683-af25-b40c2332b2fe', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'EOU', false, '2025-05-22 10:41:18.749919+00', '2025-05-22 10:41:18.749919+00'),
	('8c80c97d-010e-455e-bd7f-68dfccc27043', 'f47ac10b-58cc-4372-a567-0e02b2c3d480', 'SDEC', false, '2025-05-22 17:33:45.432994+00', '2025-05-22 17:33:45.432994+00'),
	('81c30d93-8712-405c-ac5e-509d48fd9af9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'AMU', true, '2025-05-23 14:37:07.660982+00', '2025-05-23 14:37:10.792334+00');


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."staff" ("id", "first_name", "last_name", "role", "created_at", "updated_at", "department_id") VALUES
	('f45a46c3-2240-462f-9895-494965ecd1a8', 'Michael', 'Johnson', 'porter', '2025-05-22 12:37:46.596932+00', '2025-05-22 12:57:04.760181+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d485'),
	('ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'Porter', 'Two', 'porter', '2025-05-22 15:14:27.136064+00', '2025-05-22 15:14:27.136064+00', NULL),
	('75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'Porter', 'Three', 'porter', '2025-05-22 15:14:47.797324+00', '2025-05-22 15:14:47.797324+00', NULL),
	('4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'Martin', 'Smith', 'supervisor', '2025-05-22 16:38:43.142566+00', '2025-05-22 16:38:43.142566+00', NULL),
	('b88b49d1-c394-491e-aaa7-cc196250f0e4', 'Martin', 'Fearon', 'supervisor', '2025-05-22 12:36:39.488519+00', '2025-05-22 16:38:53.581199+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484'),
	('358aa759-e11e-40b0-b886-37481c5eb6c0', 'Chris', 'Chrombie', 'supervisor', '2025-05-22 16:39:03.319212+00', '2025-05-22 16:39:03.319212+00', NULL),
	('a9d969e3-d449-4005-a679-f63be07c6872', 'Luke', 'Clements', 'supervisor', '2025-05-22 16:39:16.282662+00', '2025-05-22 16:39:16.282662+00', NULL),
	('786d6d23-69b9-433e-92ed-938806cb10a8', 'Porter', 'Four', 'porter', '2025-05-23 14:15:42.030594+00', '2025-05-23 14:15:42.030594+00', NULL),
	('676e6634-937d-4c65-a165-55ad78b9dde4', 'Ami', 'Horrocks', 'supervisor', '2025-05-23 14:36:19.660696+00', '2025-05-23 14:36:29.035914+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d486'),
	('394d8660-7946-4b31-87c9-b60f7e1bc294', 'Porter', 'Five', 'porter', '2025-05-23 14:36:44.275665+00', '2025-05-23 14:36:51.289918+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484');


--
-- Data for Name: area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_assignments" ("id", "department_id", "porter_id", "start_time", "end_time", "color", "created_at", "updated_at", "shift_type") VALUES
	('30996744-4aea-4fce-a661-f97a6ab0ad9e', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', NULL, '09:00:00', '17:00:00', '#EA4335', '2025-05-22 14:23:42.63881+00', '2025-05-23 12:59:19.115619+00', 'week_day'),
	('da7c9105-d530-4b40-b3db-1e7a73145b70', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-22 14:23:42.63881+00', '2025-05-23 12:59:19.115619+00', 'week_night'),
	('b839a39a-ead1-4542-8cc9-0c9bfc0bb8d0', '831035d1-93e9-4683-af25-b40c2332b2fe', NULL, '22:00:00', '06:00:00', '#34A853', '2025-05-22 14:23:42.63881+00', '2025-05-23 12:59:19.115619+00', 'week_night'),
	('b560c26d-710d-46bb-b8ec-29a3f47857fe', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f45a46c3-2240-462f-9895-494965ecd1a8', '08:00:00', '16:00:00', '#4285F4', '2025-05-22 14:23:42.63881+00', '2025-05-23 12:59:19.115619+00', 'week_day'),
	('37dd18e2-a152-4d8e-bd75-2c4b57e23f24', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-23 13:54:58.91758+00', '2025-05-23 13:54:58.91758+00', 'weekend_day'),
	('1c133e17-8f96-4960-a13e-754e71d6f408', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-23 14:00:09.395045+00', '2025-05-23 14:00:09.395045+00', 'weekend_night'),
	('abac3b75-8e95-4557-9a80-527fa225e63a', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', NULL, '08:00:00', '16:00:00', '#f143f4', '2025-05-22 14:31:17.181485+00', '2025-05-23 14:14:47.117695+00', 'week_day');


--
-- Data for Name: area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_porter_assignments" ("id", "area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('1720cc56-dbe7-4708-b2eb-a486fa49870b', 'abac3b75-8e95-4557-9a80-527fa225e63a', 'f45a46c3-2240-462f-9895-494965ecd1a8', '08:00:00', '09:00:00', '2025-05-22 14:58:12.027621+00', '2025-05-23 14:14:47.207882+00'),
	('5c568bc8-000e-42cb-8474-3d3aa16252b8', 'abac3b75-8e95-4557-9a80-527fa225e63a', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '09:00:00', '14:00:00', '2025-05-22 15:19:19.700741+00', '2025-05-23 14:14:47.356608+00'),
	('82fd685c-504b-4ab4-885c-9d39ff733649', 'abac3b75-8e95-4557-9a80-527fa225e63a', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '14:00:00', '15:59:00', '2025-05-22 15:34:42.044143+00', '2025-05-23 14:14:47.47818+00');


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shifts" ("id", "supervisor_id", "shift_type", "start_time", "end_time", "is_active", "created_at", "updated_at") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d492', 'a9d969e3-d449-4005-a679-f63be07c6872', 'day', '2025-05-22 08:24:46.89275+00', '2025-05-22 16:24:46.89275+00', false, '2025-05-22 08:24:46.89275+00', '2025-05-23 08:24:46.89275+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d491', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'night', '2025-05-23 05:24:46.89275+00', '2025-05-23 14:15:54.406+00', false, '2025-05-23 08:24:46.89275+00', '2025-05-23 14:15:54.724487+00'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d490', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'day', '2025-05-23 06:24:46.89275+00', '2025-05-23 14:15:59.682+00', false, '2025-05-23 08:24:46.89275+00', '2025-05-23 14:16:00.001677+00'),
	('eca831e9-fa9f-4604-9526-0a6f70040f86', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'day', '2025-05-23 08:47:36.33+00', '2025-05-23 14:16:03.596+00', false, '2025-05-23 08:47:36.411612+00', '2025-05-23 14:16:03.931319+00'),
	('4052b05b-ecee-49f4-87d3-23411235d269', 'a9d969e3-d449-4005-a679-f63be07c6872', 'day', '2025-05-23 12:38:55.9+00', '2025-05-23 14:16:08.077+00', false, '2025-05-23 12:38:55.993243+00', '2025-05-23 14:16:08.422501+00'),
	('17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'a9d969e3-d449-4005-a679-f63be07c6872', 'night', '2025-05-23 13:17:58.966+00', '2025-05-23 14:16:51.017+00', false, '2025-05-23 13:17:59.136287+00', '2025-05-23 14:16:51.36234+00'),
	('8825d646-0ce3-4bba-a2bc-83d62a5e8154', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'night', '2025-05-23 13:20:37.387+00', '2025-05-23 14:16:54.573+00', false, '2025-05-23 13:20:37.565328+00', '2025-05-23 14:16:54.896036+00'),
	('491aa067-1889-4f0e-b125-b12085ad68e9', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'day', '2025-05-23 13:17:47.666+00', '2025-05-23 14:16:58.495+00', false, '2025-05-23 13:17:47.839917+00', '2025-05-23 14:16:58.866477+00'),
	('90306217-712e-4cc6-a216-a3116b249351', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'day', '2025-05-23 13:47:44.758+00', '2025-05-23 14:17:02.142+00', false, '2025-05-23 13:47:45.024518+00', '2025-05-23 14:17:02.473504+00'),
	('c858cdeb-2065-4e07-b7c6-05e4f01a50c4', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'day', '2025-05-23 14:00:45.451+00', '2025-05-23 14:17:06.104+00', false, '2025-05-23 14:00:45.685827+00', '2025-05-23 14:17:06.428454+00'),
	('1dd40f71-1975-4cce-bd8e-d29f8757335d', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'day', '2025-05-24 06:51:02.239+00', '2025-05-24 07:19:11.357+00', false, '2025-05-24 06:51:02.356014+00', '2025-05-24 07:19:11.511708+00'),
	('a97ed598-dc7a-4a15-a8a1-22c49f7fe56d', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'day', '2025-05-24 06:38:27.344+00', '2025-05-24 07:20:21.135+00', false, '2025-05-24 06:38:27.439212+00', '2025-05-24 07:20:21.276726+00'),
	('9d9682b6-dc0b-4440-bf64-402e785a1f14', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'day', '2025-05-24 06:21:27.548+00', '2025-05-24 07:20:24.533+00', false, '2025-05-24 06:21:27.634885+00', '2025-05-24 07:20:24.674434+00'),
	('169b7839-e53f-46d6-80f4-fdedc4742a2d', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'day', '2025-05-24 06:10:59.208+00', '2025-05-24 07:20:27.898+00', false, '2025-05-24 06:10:59.325318+00', '2025-05-24 07:20:28.039936+00'),
	('804e35b7-b171-4a98-90b8-fa44a7220e13', '676e6634-937d-4c65-a165-55ad78b9dde4', 'day', '2025-05-24 06:02:56.662+00', '2025-05-24 07:20:31.212+00', false, '2025-05-24 06:02:56.778016+00', '2025-05-24 07:20:31.353674+00'),
	('e57acaf6-f171-42c5-958d-24ac48479180', 'a9d969e3-d449-4005-a679-f63be07c6872', 'day', '2025-05-23 14:34:47.539+00', '2025-05-24 07:20:34.33+00', false, '2025-05-23 14:34:47.882072+00', '2025-05-24 07:20:34.467963+00'),
	('2e765b10-6ff6-4a88-8ede-ba75777e0323', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'day', '2025-05-23 14:17:14.666+00', '2025-05-24 07:20:37.996+00', false, '2025-05-23 14:17:14.961879+00', '2025-05-24 07:20:38.132798+00'),
	('ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'day', '2025-05-24 07:20:48.416+00', NULL, true, '2025-05-24 07:20:48.591102+00', '2025-05-24 07:20:48.591102+00');


--
-- Data for Name: shift_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_assignments" ("id", "shift_id", "department_id", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('2419f2a2-0ca1-4bde-b400-e270a891376a', '4052b05b-ecee-49f4-87d3-23411235d269', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 12:38:56.253208+00', '2025-05-23 12:38:56.253208+00'),
	('cef3761d-3482-43b2-8f8d-1b1e7cf7ecee', '4052b05b-ecee-49f4-87d3-23411235d269', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:38:56.253208+00', '2025-05-23 12:38:56.253208+00'),
	('f0692dfd-6490-43d9-a510-07a8ea9a8de5', '4052b05b-ecee-49f4-87d3-23411235d269', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:38:56.253208+00', '2025-05-23 12:38:56.253208+00'),
	('e165d278-7959-4135-b3eb-748306d3dde0', '4052b05b-ecee-49f4-87d3-23411235d269', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:38:56.253208+00', '2025-05-23 12:38:56.253208+00'),
	('cc08cea8-8025-4e56-925b-d5dcd3fd55f9', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('0c72ef0b-5e3b-421b-8e13-2f84ef1d2ef2', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('ed5f6696-e09e-442a-b5d2-93df694b30c0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('5e705b74-8d60-45f1-8afa-b8dfa41f7192', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('6899bf05-51f9-47fa-97c2-3314f7c404b5', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '20:00:00', '04:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('1f62f634-3e63-4004-ac08-c955b9b135ff', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', '831035d1-93e9-4683-af25-b40c2332b2fe', '22:00:00', '06:00:00', '#34A853', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('f0fd4437-91d8-4a1a-bf81-2d8194852d77', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('5c69219f-a81f-41d2-a972-510535785b6b', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('c632f3ad-c5fc-46f5-ac4b-cd0462972b92', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('ff28c3be-51e3-44f6-878e-9795826a05e6', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('afa77f2f-38bc-456e-a10d-b4dcf1b9df50', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('7c495d1b-cfc1-4f79-87df-f11dd0e828c5', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('84aacfe3-2fae-4969-9b30-b21501a35384', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('36dc00c7-0dfe-4f71-a11a-1bdd7599cd43', 'eca831e9-fa9f-4604-9526-0a6f70040f86', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 12:43:11.927251+00', '2025-05-23 12:43:11.927251+00'),
	('1125666a-41a4-437c-b004-cafaf292adc3', '491aa067-1889-4f0e-b125-b12085ad68e9', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 13:17:48.022048+00', '2025-05-23 13:17:48.022048+00'),
	('e56f3a7d-e436-4db4-b03f-338188b8f7f6', '491aa067-1889-4f0e-b125-b12085ad68e9', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 13:17:48.022048+00', '2025-05-23 13:17:48.022048+00'),
	('e1b481f3-6406-43d9-8e37-bc32b783c891', '491aa067-1889-4f0e-b125-b12085ad68e9', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:17:48.022048+00', '2025-05-23 13:17:48.022048+00'),
	('9472d72c-af1f-49fd-8189-892bf0cc9d2e', '491aa067-1889-4f0e-b125-b12085ad68e9', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:17:48.022048+00', '2025-05-23 13:17:48.022048+00'),
	('25312b44-b73f-459a-98b0-f1cf4c3f429d', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00'),
	('b2ad2268-c8c5-4680-a679-d86a0af9d6b3', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00'),
	('402fc097-494d-4468-8e97-3c21ec22d6af', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00'),
	('b767566b-5d75-4ccb-86ae-0efef2a4dd16', '17b46dce-3af4-4e96-8bfc-d8145e3c3a0c', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:17:59.288837+00', '2025-05-23 13:17:59.288837+00'),
	('6677967f-cbe0-4d24-9555-28762e3da054', '8825d646-0ce3-4bba-a2bc-83d62a5e8154', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 13:20:37.741694+00', '2025-05-23 13:20:37.741694+00'),
	('04b9beb4-b522-4b5d-8988-b6ddddd251f0', '8825d646-0ce3-4bba-a2bc-83d62a5e8154', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 13:20:37.741694+00', '2025-05-23 13:20:37.741694+00'),
	('fc32de10-18df-4a91-bb31-2d0eeb30831b', '8825d646-0ce3-4bba-a2bc-83d62a5e8154', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:20:37.741694+00', '2025-05-23 13:20:37.741694+00'),
	('56b1ddc5-1d28-470b-b49a-11f980422d8e', '8825d646-0ce3-4bba-a2bc-83d62a5e8154', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:20:37.741694+00', '2025-05-23 13:20:37.741694+00'),
	('4d669de9-d3c4-4e56-a275-4375cd27d530', '90306217-712e-4cc6-a216-a3116b249351', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 13:47:45.219469+00', '2025-05-23 13:47:45.219469+00'),
	('33498c57-595d-4a9d-abe1-07c04fad6b04', '90306217-712e-4cc6-a216-a3116b249351', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '07:30:00', '15:30:00', '#FBBC05', '2025-05-23 13:47:45.219469+00', '2025-05-23 13:47:45.219469+00'),
	('53d8870d-b055-43ea-b73e-e457304eb721', '90306217-712e-4cc6-a216-a3116b249351', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:47:45.219469+00', '2025-05-23 13:47:45.219469+00'),
	('20b3e5b8-1f7e-4e60-b19c-bbb58fd52cee', '90306217-712e-4cc6-a216-a3116b249351', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:47:45.219469+00', '2025-05-23 13:47:45.219469+00'),
	('738ba7a9-7b35-44a3-9a2e-6798680445ea', '90306217-712e-4cc6-a216-a3116b249351', '8c80c97d-010e-455e-bd7f-68dfccc27043', '20:00:00', '04:00:00', '#4285F4', '2025-05-23 13:48:24.657486+00', '2025-05-23 13:48:24.657486+00'),
	('02b5231e-a024-4427-9ca7-a5086174f710', 'c858cdeb-2065-4e07-b7c6-05e4f01a50c4', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 14:00:45.866672+00', '2025-05-23 14:00:45.866672+00'),
	('33b8bb65-b5be-4c06-9421-e27a496782e8', 'c858cdeb-2065-4e07-b7c6-05e4f01a50c4', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 14:00:45.866672+00', '2025-05-23 14:00:45.866672+00'),
	('c5785e2b-c269-4f65-81d8-f198ce6c3b45', '2e765b10-6ff6-4a88-8ede-ba75777e0323', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 14:17:15.13255+00', '2025-05-23 14:17:15.13255+00'),
	('f287bab8-fdaf-42db-91dd-e03be352ffa5', '2e765b10-6ff6-4a88-8ede-ba75777e0323', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 14:17:15.13255+00', '2025-05-23 14:17:15.13255+00'),
	('1a44d067-3a93-41fc-8d20-f7c85dcef640', '2e765b10-6ff6-4a88-8ede-ba75777e0323', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-23 14:17:15.13255+00', '2025-05-23 14:17:15.13255+00'),
	('b4dc68be-c543-4ec9-8843-020ddf06606b', 'e57acaf6-f171-42c5-958d-24ac48479180', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-23 14:34:48.058676+00', '2025-05-23 14:34:48.058676+00'),
	('d52f4ddd-c429-4439-bba1-a65cd4386b4d', 'e57acaf6-f171-42c5-958d-24ac48479180', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 14:34:48.058676+00', '2025-05-23 14:34:48.058676+00'),
	('e89157b5-1ff3-4183-8afb-569f652294dd', 'e57acaf6-f171-42c5-958d-24ac48479180', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-23 14:34:48.058676+00', '2025-05-23 14:34:48.058676+00'),
	('d980e0d1-235a-4fe5-b84f-f85a1a707e03', 'e57acaf6-f171-42c5-958d-24ac48479180', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', '20:00:00', '04:00:00', '#4285F4', '2025-05-23 14:35:41.874538+00', '2025-05-23 14:35:41.874538+00'),
	('cf58e319-1ef8-4192-b8c4-e8f68c1ed1c4', '804e35b7-b171-4a98-90b8-fa44a7220e13', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-24 06:02:57.009299+00', '2025-05-24 06:02:57.009299+00'),
	('ed014827-c524-4347-bf99-d60722640c7e', '804e35b7-b171-4a98-90b8-fa44a7220e13', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-24 06:02:57.009299+00', '2025-05-24 06:02:57.009299+00'),
	('b826ba6f-316b-4ee3-b545-2851a06af2d6', '804e35b7-b171-4a98-90b8-fa44a7220e13', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-24 06:02:57.009299+00', '2025-05-24 06:02:57.009299+00'),
	('1ab7af8d-5efc-4311-9b85-74e3d15cc7ba', '169b7839-e53f-46d6-80f4-fdedc4742a2d', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-24 06:10:59.463568+00', '2025-05-24 06:10:59.463568+00'),
	('3e6cece0-f0ad-4aee-ad0a-7b4ae389f0d0', '169b7839-e53f-46d6-80f4-fdedc4742a2d', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-24 06:10:59.463568+00', '2025-05-24 06:10:59.463568+00'),
	('686a51db-97cc-45a7-bf96-8e5eb47fb869', '169b7839-e53f-46d6-80f4-fdedc4742a2d', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-24 06:10:59.463568+00', '2025-05-24 06:10:59.463568+00'),
	('cc3ec690-c039-4f4b-a51a-1b9d496578da', '9d9682b6-dc0b-4440-bf64-402e785a1f14', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-24 06:21:27.798426+00', '2025-05-24 06:21:27.798426+00'),
	('9a4e7061-973e-4fa7-b753-b7b04800a18b', '9d9682b6-dc0b-4440-bf64-402e785a1f14', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-24 06:21:27.798426+00', '2025-05-24 06:21:27.798426+00'),
	('fdd17486-a0a1-468e-968e-0d2e9142592e', '9d9682b6-dc0b-4440-bf64-402e785a1f14', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-24 06:21:27.798426+00', '2025-05-24 06:21:27.798426+00'),
	('1fc8028d-da06-4068-b2b0-87c4bf930ac5', 'a97ed598-dc7a-4a15-a8a1-22c49f7fe56d', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-24 06:38:27.59245+00', '2025-05-24 06:38:27.59245+00'),
	('19ef793a-c0da-45fc-b257-fe5e54e5bd7b', 'a97ed598-dc7a-4a15-a8a1-22c49f7fe56d', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-24 06:38:27.59245+00', '2025-05-24 06:38:27.59245+00'),
	('c68890c8-de8b-4aff-bfa0-4fe63a077fab', 'a97ed598-dc7a-4a15-a8a1-22c49f7fe56d', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-24 06:38:27.59245+00', '2025-05-24 06:38:27.59245+00'),
	('cb79ebe6-3977-490e-92df-43a5e6a976ae', '1dd40f71-1975-4cce-bd8e-d29f8757335d', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-24 06:51:02.517619+00', '2025-05-24 06:51:02.517619+00'),
	('25748fb2-2e2b-4572-b0f3-e6f4db660498', '1dd40f71-1975-4cce-bd8e-d29f8757335d', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-24 06:51:02.517619+00', '2025-05-24 06:51:02.517619+00'),
	('1e2835a0-de76-4542-bf87-b4fa22ead6bb', '1dd40f71-1975-4cce-bd8e-d29f8757335d', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-24 06:51:02.517619+00', '2025-05-24 06:51:02.517619+00'),
	('23125ee6-fbba-495f-8b95-fa7a3a8a17c4', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', '09:00:00', '17:00:00', '#EA4335', '2025-05-24 07:20:48.772587+00', '2025-05-24 07:20:48.772587+00'),
	('2bad00b4-3738-42d5-902a-31bee281cb19', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '08:00:00', '16:00:00', '#4285F4', '2025-05-24 07:20:48.772587+00', '2025-05-24 07:20:48.772587+00'),
	('1af3ac85-a355-4906-ba2d-b020f412fc30', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '08:00:00', '16:00:00', '#f143f4', '2025-05-24 07:20:48.772587+00', '2025-05-24 07:20:48.772587+00');


--
-- Data for Name: shift_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_porter_assignments" ("id", "shift_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('97f00c3c-9fbf-4cf5-bbd7-62cc17560f08', '738ba7a9-7b35-44a3-9a2e-6798680445ea', 'f45a46c3-2240-462f-9895-494965ecd1a8', '20:00:00', '04:00:00', '2025-05-23 13:48:34.33182+00', '2025-05-23 13:48:34.33182+00'),
	('7fc23522-cbd4-484e-8dab-7e0976133589', '33498c57-595d-4a9d-abe1-07c04fad6b04', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '12:30:00', '20:30:00', '2025-05-23 13:48:58.885708+00', '2025-05-23 13:48:58.885708+00'),
	('5c6d1d2d-f464-47cc-b62f-0cb0024be242', '33b8bb65-b5be-4c06-9421-e27a496782e8', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '08:00:00', '16:00:00', '2025-05-23 14:01:47.707145+00', '2025-05-23 14:01:47.707145+00'),
	('74cedb85-0d21-46cc-856a-ab2c1c8ce9be', 'fdd17486-a0a1-468e-968e-0d2e9142592e', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '09:00:00', '14:00:00', '2025-05-24 06:21:27.919014+00', '2025-05-24 06:21:27.919014+00'),
	('b1ad5839-ac1f-4b86-b3a0-2aeffb12d355', 'fdd17486-a0a1-468e-968e-0d2e9142592e', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '14:00:00', '15:59:00', '2025-05-24 06:21:27.919014+00', '2025-05-24 06:21:27.919014+00'),
	('0b0932e6-2c1d-4b00-9b03-55494882457f', 'fdd17486-a0a1-468e-968e-0d2e9142592e', 'f45a46c3-2240-462f-9895-494965ecd1a8', '10:00:00', '09:00:00', '2025-05-24 06:21:27.919014+00', '2025-05-24 06:21:27.919014+00'),
	('3b58183b-42ca-407a-9ba0-fceb5763af0f', 'c68890c8-de8b-4aff-bfa0-4fe63a077fab', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '09:00:00', '14:00:00', '2025-05-24 06:38:27.678243+00', '2025-05-24 06:38:27.678243+00'),
	('4419eb60-eeab-4965-8a40-a132bbe12bd5', 'c68890c8-de8b-4aff-bfa0-4fe63a077fab', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '14:00:00', '15:59:00', '2025-05-24 06:38:27.678243+00', '2025-05-24 06:38:27.678243+00'),
	('8754aee0-bd74-4e61-acc2-b0453dd50a49', '1e2835a0-de76-4542-bf87-b4fa22ead6bb', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-24 07:13:13.22587+00', '2025-05-24 07:13:13.22587+00'),
	('5111433b-ade5-47c3-bb56-139c0c4bde86', '1af3ac85-a355-4906-ba2d-b020f412fc30', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '09:00:00', '14:00:00', '2025-05-24 07:20:48.86083+00', '2025-05-24 07:20:48.86083+00'),
	('789c545b-04bb-46fd-8775-b03ab80c2c45', '1af3ac85-a355-4906-ba2d-b020f412fc30', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-24 07:21:18.843292+00', '2025-05-24 07:21:18.843292+00');


--
-- Data for Name: shift_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_defaults" ("id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('85cc4d8d-f0fc-477a-b138-56efdcbfcdf1', 'week_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('01373b67-60e9-4422-a1ae-a8e72d119014', 'week_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('2b13f0ba-98fc-4013-9953-0da1418e8ea0', 'weekend_day', '08:00:00', '16:00:00', '#34A853', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('524485d0-141a-4574-808b-93410f62ca94', 'weekend_night', '20:00:00', '08:00:00', '#EA4335', '2025-05-23 13:34:38.657478+00', '2025-05-23 13:34:38.657478+00'),
	('f6a391c3-2e65-4b33-ad43-76857a81aa4d', 'night', '20:00:00', '08:00:00', '#673AB7', '2025-05-22 16:22:03.801345+00', '2025-05-23 14:00:29.815+00'),
	('8472931e-f2fd-4827-a444-ab4827e706d2', 'day', '08:00:00', '16:00:00', '#4285F4', '2025-05-22 16:22:03.801345+00', '2025-05-23 14:00:29.814+00');


--
-- Data for Name: shift_porter_pool; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_porter_pool" ("id", "shift_id", "porter_id", "created_at", "updated_at") VALUES
	('bcf98922-4398-4827-94df-c942d6de5029', '2e765b10-6ff6-4a88-8ede-ba75777e0323', 'f45a46c3-2240-462f-9895-494965ecd1a8', '2025-05-24 05:56:01.616834+00', '2025-05-24 05:56:01.616834+00'),
	('d6feee0d-d848-4384-b853-9213c4111d6f', '2e765b10-6ff6-4a88-8ede-ba75777e0323', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-24 05:56:01.616834+00', '2025-05-24 05:56:01.616834+00'),
	('9db8bff8-daba-4e39-aef7-2d9d463377a7', '2e765b10-6ff6-4a88-8ede-ba75777e0323', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-24 05:56:01.616834+00', '2025-05-24 05:56:01.616834+00'),
	('32f018aa-8c4c-4513-acae-100d1cb645da', '2e765b10-6ff6-4a88-8ede-ba75777e0323', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-24 05:56:01.616834+00', '2025-05-24 05:56:01.616834+00'),
	('2bf5245a-b84b-485d-bc6f-a071ca28fc08', '804e35b7-b171-4a98-90b8-fa44a7220e13', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-24 06:08:29.345742+00', '2025-05-24 06:08:29.345742+00'),
	('1560a662-e4d8-486a-911d-01fbea7622ee', '9d9682b6-dc0b-4440-bf64-402e785a1f14', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-24 06:23:05.919826+00', '2025-05-24 06:23:05.919826+00'),
	('6bca1918-5388-48bc-ab7a-ae8a1ad62503', '9d9682b6-dc0b-4440-bf64-402e785a1f14', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-24 06:23:08.874303+00', '2025-05-24 06:23:08.874303+00'),
	('e0f46ee0-5d97-4c47-8e65-db6ecbcf046d', 'a97ed598-dc7a-4a15-a8a1-22c49f7fe56d', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-24 06:42:51.500319+00', '2025-05-24 06:42:51.500319+00'),
	('4223e83a-7635-404c-82a7-9fb23c26e05d', 'a97ed598-dc7a-4a15-a8a1-22c49f7fe56d', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-24 06:49:59.232666+00', '2025-05-24 06:49:59.232666+00'),
	('51467abe-4681-4c09-b004-5748c93f62dd', '1dd40f71-1975-4cce-bd8e-d29f8757335d', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-24 07:12:42.210492+00', '2025-05-24 07:12:42.210492+00'),
	('687daaf3-a8fc-4540-ab41-cd46f745662d', '1dd40f71-1975-4cce-bd8e-d29f8757335d', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-24 07:18:55.668868+00', '2025-05-24 07:18:55.668868+00'),
	('429e7f5f-cddb-4e18-ad3f-db58019d8ce0', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', 'f45a46c3-2240-462f-9895-494965ecd1a8', '2025-05-24 07:20:59.608657+00', '2025-05-24 07:20:59.608657+00'),
	('d3de37a7-e645-4de5-a555-1de055a78416', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-24 07:21:04.162494+00', '2025-05-24 07:21:04.162494+00'),
	('5ba33927-dc22-4fa4-b2a0-c622f1f49cbc', 'ac4d504d-8fe0-4706-b4fc-1ce9e84c483d', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-24 07:21:26.513749+00', '2025-05-24 07:21:26.513749+00');


--
-- Data for Name: task_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_types" ("id", "name", "description", "created_at", "updated_at") VALUES
	('f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Patient Transport', 'Tasks related to moving patients between departments', '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Equipment Transfer', 'Tasks related to moving equipment between departments', '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Specimen Delivery', 'Tasks related to delivering specimens to labs', '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('b864ed57-5547-404e-9459-1641a030974e', 'Asset Delivery', NULL, '2025-05-22 11:24:42.733351+00', '2025-05-22 11:24:42.733351+00'),
	('a97d8a74-0e16-4e1f-908e-96e935d91002', 'Gasesssss', NULL, '2025-05-22 11:24:51.97167+00', '2025-05-22 12:00:00.205001+00');


--
-- Data for Name: task_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_items" ("id", "task_type_id", "name", "description", "created_at", "updated_at") VALUES
	('68e8e006-79dc-4d5f-aed0-20755d53403b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Wheelchair Transport', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('14446938-25cd-4655-ad84-dbb7db871f28', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Bed Transport', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('532b14f0-042a-4ddf-bc7d-cb95ff298132', 'bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'IV Pump Transfer', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('0c90fbec-5d4c-46c0-b7dd-47fba327e3ed', 'bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Monitor Transfer', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Blood Sample Delivery', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('516e8952-a09b-456b-926d-e78411490a6d', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Tissue Sample Delivery', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-22 11:12:54.89695+00'),
	('e6068d5d-4bc5-4358-8bae-ed23759dc733', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen F Size', NULL, '2025-05-22 11:25:09.159861+00', '2025-05-22 11:25:09.159861+00'),
	('8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed (Complete)', NULL, '2025-05-22 12:00:44.450407+00', '2025-05-22 12:00:44.450407+00'),
	('a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed Frame', NULL, '2025-05-22 12:00:52.076144+00', '2025-05-22 12:00:52.076144+00');


--
-- Data for Name: shift_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at") VALUES
	('724f2648-0b08-41a6-8321-91619e0dbabb', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '14446938-25cd-4655-ad84-dbb7db871f28', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'completed', '2025-05-23 07:24:46.89275+00', '2025-05-23 08:24:46.89275+00'),
	('5e939454-7477-43e5-b5f3-65675d3e0ec7', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-05-23 06:24:46.89275+00', '2025-05-23 08:24:46.89275+00'),
	('919ef224-d90e-4aac-8e52-dfa25ada730a', 'f47ac10b-58cc-4372-a567-0e02b2c3d491', '0c90fbec-5d4c-46c0-b7dd-47fba327e3ed', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:24:46.89275+00'),
	('0e7dce68-352e-413a-a061-20fb11aa1ab0', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'f45a46c3-2240-462f-9895-494965ecd1a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-22 08:24:46.89275+00', '2025-05-22 09:24:46.89275+00'),
	('4a06494e-1051-4006-b130-d72b4a6eebf1', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '516e8952-a09b-456b-926d-e78411490a6d', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-22 08:24:46.89275+00', '2025-05-22 10:24:46.89275+00'),
	('74f81abd-0b5b-465d-a979-fa6dce4c276d', 'f47ac10b-58cc-4372-a567-0e02b2c3d492', '14446938-25cd-4655-ad84-dbb7db871f28', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'pending', '2025-05-22 12:24:46.89275+00', '2025-05-22 12:24:46.89275+00'),
	('37ef35c9-6670-494d-871a-8eb16248720e', 'eca831e9-fa9f-4604-9526-0a6f70040f86', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'f45a46c3-2240-462f-9895-494965ecd1a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'pending', '2025-05-23 08:49:55.479887+00', '2025-05-23 08:50:01.281131+00'),
	('a5638fbf-2bfe-4805-be92-13d3bdab7be0', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '68e8e006-79dc-4d5f-aed0-20755d53403b', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:54:22.695648+00'),
	('6e25558d-f989-49ce-8d40-c5b69f1af256', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', 'pending', '2025-05-23 08:24:46.89275+00', '2025-05-23 08:55:02.635556+00'),
	('8f16befe-a495-4b05-840d-cc077a569ad3', 'f47ac10b-58cc-4372-a567-0e02b2c3d490', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-23 09:21:47.358281+00', '2025-05-23 09:21:47.358281+00'),
	('b57eb494-5648-4d1d-b783-aa48eced023a', 'e57acaf6-f171-42c5-958d-24ac48479180', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'f47ac10b-58cc-4372-a567-0e02b2c3d488', 'completed', '2025-05-23 14:35:11.683807+00', '2025-05-23 14:35:22.324033+00'),
	('1b91132f-6967-47a1-9b13-7d020244f6e6', 'e57acaf6-f171-42c5-958d-24ac48479180', '0c90fbec-5d4c-46c0-b7dd-47fba327e3ed', '786d6d23-69b9-433e-92ed-938806cb10a8', 'f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', 'completed', '2025-05-23 14:38:42.170724+00', '2025-05-23 14:38:50.047597+00');


--
-- Data for Name: staff_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: task_item_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_item_department_assignments" ("id", "task_item_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('202e214c-d391-4d31-9420-19107d09e369', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', true, false, '2025-05-22 11:48:58.554953+00'),
	('6d4a3a95-a59f-4f1a-acc3-ecec0ceb4f5c', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', false, true, '2025-05-22 11:48:58.554953+00'),
	('336ab3af-d830-4fcf-aa23-e53cba549683', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'f47ac10b-58cc-4372-a567-0e02b2c3d486', true, false, '2025-05-23 14:37:40.82257+00'),
	('e6e14b1e-d39f-48c3-8516-501b7ae7a164', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', false, true, '2025-05-23 14:37:40.82257+00');


--
-- Data for Name: task_type_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_type_department_assignments" ("id", "task_type_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('8ad6f923-15fb-4b1d-9343-7d571fb9e983', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', true, false, '2025-05-22 11:22:54.496017+00'),
	('8e26b00d-8001-4d1c-8e07-7301a034f5dc', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', false, true, '2025-05-22 11:22:54.496017+00'),
	('044347c0-6a23-42b9-9907-72f2c8547709', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '831035d1-93e9-4683-af25-b40c2332b2fe', false, true, '2025-05-22 11:23:47.367207+00'),
	('d8356887-ab0e-42ef-8d95-bfddfe91f1ce', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', true, false, '2025-05-22 11:23:47.367207+00'),
	('50c8607f-9c29-4544-bbde-780502674f3a', 'bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'f47ac10b-58cc-4372-a567-0e02b2c3d485', true, false, '2025-05-22 11:48:30.622979+00');


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
