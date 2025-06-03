

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


CREATE OR REPLACE FUNCTION "public"."copy_defaults_on_shift_creation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  PERFORM copy_defaults_to_shift(NEW.id, NEW.shift_type);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."copy_defaults_on_shift_creation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_area_cover_assignment_id UUID;
  v_service_cover_assignment_id UUID;
  v_default_area_cover_id UUID;
  v_default_service_cover_id UUID;
  r_area_assignment RECORD;
  r_service_assignment RECORD;
  r_area_porter RECORD;
  r_service_porter RECORD;
  v_porter_count INTEGER;
  v_debug_info TEXT;
BEGIN
  -- Initialize debug info
  v_debug_info := 'Starting copy_defaults_to_shift for shift_id: ' || p_shift_id || ', shift_type: ' || p_shift_type;

  -- Copy area cover assignments from defaults to shift
  FOR r_area_assignment IN
    SELECT * FROM default_area_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := v_debug_info || E'\nProcessing area cover assignment: ' || r_area_assignment.id;

    -- Insert into shift_area_cover_assignments with day-specific minimum porter counts
    INSERT INTO shift_area_cover_assignments (
      shift_id, department_id, start_time, end_time, color,
      minimum_porters, minimum_porters_mon, minimum_porters_tue, 
      minimum_porters_wed, minimum_porters_thu, minimum_porters_fri, 
      minimum_porters_sat, minimum_porters_sun
    ) VALUES (
      p_shift_id, r_area_assignment.department_id, r_area_assignment.start_time,
      r_area_assignment.end_time, r_area_assignment.color,
      r_area_assignment.minimum_porters, r_area_assignment.minimum_porters_mon, 
      r_area_assignment.minimum_porters_tue, r_area_assignment.minimum_porters_wed, 
      r_area_assignment.minimum_porters_thu, r_area_assignment.minimum_porters_fri, 
      r_area_assignment.minimum_porters_sat, r_area_assignment.minimum_porters_sun
    ) RETURNING id INTO v_area_cover_assignment_id;

    -- Store the default ID for later
    v_default_area_cover_id := r_area_assignment.id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Created shift_area_cover_assignment: ' || v_area_cover_assignment_id;

    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count
    FROM default_area_cover_porter_assignments
    WHERE default_area_cover_assignment_id = v_default_area_cover_id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Found ' || v_porter_count || ' porter assignments to copy';

    -- Copy porter assignments for this area cover
    FOR r_area_porter IN
      SELECT * FROM default_area_cover_porter_assignments
      WHERE default_area_cover_assignment_id = v_default_area_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Processing porter assignment: ' || r_area_porter.id;

      INSERT INTO shift_area_cover_porter_assignments (
        shift_area_cover_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_area_cover_assignment_id, r_area_porter.porter_id,
        r_area_porter.start_time, r_area_porter.end_time
      );

      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Created porter assignment for porter_id: ' || r_area_porter.porter_id;
    END LOOP;
  END LOOP;

  -- Copy service cover assignments from defaults to shift
  FOR r_service_assignment IN
    SELECT * FROM default_service_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := v_debug_info || E'\nProcessing service cover assignment: ' || r_service_assignment.id;

    -- Insert into shift_support_service_assignments with day-specific minimum porter counts
    INSERT INTO shift_support_service_assignments (
      shift_id, service_id, start_time, end_time, color,
      minimum_porters, minimum_porters_mon, minimum_porters_tue, 
      minimum_porters_wed, minimum_porters_thu, minimum_porters_fri, 
      minimum_porters_sat, minimum_porters_sun
    ) VALUES (
      p_shift_id, r_service_assignment.service_id, r_service_assignment.start_time,
      r_service_assignment.end_time, r_service_assignment.color,
      r_service_assignment.minimum_porters, r_service_assignment.minimum_porters_mon, 
      r_service_assignment.minimum_porters_tue, r_service_assignment.minimum_porters_wed, 
      r_service_assignment.minimum_porters_thu, r_service_assignment.minimum_porters_fri, 
      r_service_assignment.minimum_porters_sat, r_service_assignment.minimum_porters_sun
    ) RETURNING id INTO v_service_cover_assignment_id;

    -- Store the default ID for later
    v_default_service_cover_id := r_service_assignment.id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Created shift_support_service_assignment: ' || v_service_cover_assignment_id;

    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count
    FROM default_service_cover_porter_assignments
    WHERE default_service_cover_assignment_id = v_default_service_cover_id;

    -- Add to debug info
    v_debug_info := v_debug_info || E'\n  Found ' || v_porter_count || ' porter assignments to copy';

    -- Copy porter assignments for this service cover
    FOR r_service_porter IN
      SELECT * FROM default_service_cover_porter_assignments
      WHERE default_service_cover_assignment_id = v_default_service_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Processing porter assignment: ' || r_service_porter.id;

      INSERT INTO shift_support_service_porter_assignments (
        shift_support_service_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_service_cover_assignment_id, r_service_porter.porter_id,
        r_service_porter.start_time, r_service_porter.end_time
      );

      -- Add to debug info
      v_debug_info := v_debug_info || E'\n  Created porter assignment for porter_id: ' || r_service_porter.porter_id;
    END LOOP;
  END LOOP;

  -- Log debug info (optional)
  -- RAISE NOTICE '%', v_debug_info;
END;
$$;


ALTER FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) IS 'Copies default area cover and service cover assignments to a new shift. 
This version includes better error handling and debugging to ensure porter assignments 
are properly copied from default_service_cover_porter_assignments to 
shift_support_service_porter_assignments.';



CREATE OR REPLACE FUNCTION "public"."update_modified_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_modified_column"() OWNER TO "postgres";


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
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0
);


ALTER TABLE "public"."buildings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "department_id" "uuid" NOT NULL,
    "shift_type" character varying(20) NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "color" character varying(20) DEFAULT '#4285F4'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1,
    CONSTRAINT "default_area_cover_assignments_shift_type_check" CHECK ((("shift_type")::"text" = ANY (ARRAY[('week_day'::character varying)::"text", ('week_night'::character varying)::"text", ('weekend_day'::character varying)::"text", ('weekend_night'::character varying)::"text"])))
);


ALTER TABLE "public"."default_area_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_area_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "default_area_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."default_area_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_service_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "service_id" "uuid" NOT NULL,
    "shift_type" character varying(20) NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "color" character varying(20) DEFAULT '#4285F4'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1,
    CONSTRAINT "default_service_cover_assignments_shift_type_check" CHECK ((("shift_type")::"text" = ANY (ARRAY[('week_day'::character varying)::"text", ('week_night'::character varying)::"text", ('weekend_day'::character varying)::"text", ('weekend_night'::character varying)::"text"])))
);


ALTER TABLE "public"."default_service_cover_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."default_service_cover_porter_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "default_service_cover_assignment_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "end_time" time without time zone DEFAULT '16:00:00'::time without time zone NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."default_service_cover_porter_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."departments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "building_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_frequent" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0
);


ALTER TABLE "public"."departments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."porter_absences" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "absence_type" character varying(20) NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "notes" "text"
);


ALTER TABLE "public"."porter_absences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_area_cover_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "department_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "color" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1
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
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "minimum_porters" integer DEFAULT 1,
    "minimum_porters_mon" integer DEFAULT 1,
    "minimum_porters_tue" integer DEFAULT 1,
    "minimum_porters_wed" integer DEFAULT 1,
    "minimum_porters_thu" integer DEFAULT 1,
    "minimum_porters_fri" integer DEFAULT 1,
    "minimum_porters_sat" integer DEFAULT 1,
    "minimum_porters_sun" integer DEFAULT 1
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
    CONSTRAINT "shifts_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."shifts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "role" "public"."staff_role" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "department_id" "uuid",
    "porter_type" "text" DEFAULT 'shift'::"text",
    "availability_pattern" character varying(50),
    "contracted_hours_start" time without time zone,
    "contracted_hours_end" time without time zone,
    CONSTRAINT "check_porter_type" CHECK ((("porter_type" = ANY (ARRAY['shift'::"text", 'relief'::"text"])) OR ("porter_type" IS NULL)))
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
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_regular" boolean DEFAULT false
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



ALTER TABLE ONLY "public"."default_area_cover_assignments"
    ADD CONSTRAINT "default_area_cover_assignments_department_id_shift_type_key" UNIQUE ("department_id", "shift_type");



ALTER TABLE ONLY "public"."default_area_cover_assignments"
    ADD CONSTRAINT "default_area_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_ass_default_area_cover_assignment_key" UNIQUE ("default_area_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."default_service_cover_assignments"
    ADD CONSTRAINT "default_service_cover_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."default_service_cover_assignments"
    ADD CONSTRAINT "default_service_cover_assignments_service_id_shift_type_key" UNIQUE ("service_id", "shift_type");



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter__default_service_cover_assignm_key" UNIQUE ("default_service_cover_assignment_id", "porter_id");



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter_assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."porter_absences"
    ADD CONSTRAINT "porter_absences_pkey" PRIMARY KEY ("id");



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



CREATE INDEX "buildings_sort_order_idx" ON "public"."buildings" USING "btree" ("sort_order");



CREATE INDEX "departments_building_id_idx" ON "public"."departments" USING "btree" ("building_id");



CREATE INDEX "departments_is_frequent_idx" ON "public"."departments" USING "btree" ("is_frequent");



CREATE INDEX "departments_sort_order_idx" ON "public"."departments" USING "btree" ("sort_order");



CREATE INDEX "idx_default_area_cover_porter_assignment" ON "public"."default_area_cover_porter_assignments" USING "btree" ("default_area_cover_assignment_id");



CREATE INDEX "idx_default_area_cover_shift_type" ON "public"."default_area_cover_assignments" USING "btree" ("shift_type");



CREATE INDEX "idx_default_service_cover_porter_assignment" ON "public"."default_service_cover_porter_assignments" USING "btree" ("default_service_cover_assignment_id");



CREATE INDEX "idx_default_service_cover_shift_type" ON "public"."default_service_cover_assignments" USING "btree" ("shift_type");



CREATE INDEX "idx_porter_absences_dates" ON "public"."porter_absences" USING "btree" ("start_date", "end_date");



CREATE INDEX "idx_porter_absences_porter_id" ON "public"."porter_absences" USING "btree" ("porter_id");



CREATE INDEX "idx_shifts_is_active" ON "public"."shifts" USING "btree" ("is_active");



CREATE INDEX "idx_shifts_supervisor_id" ON "public"."shifts" USING "btree" ("supervisor_id");



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



CREATE OR REPLACE TRIGGER "copy_defaults_to_new_shift" AFTER INSERT ON "public"."shifts" FOR EACH ROW EXECUTE FUNCTION "public"."copy_defaults_on_shift_creation"();



CREATE OR REPLACE TRIGGER "update_app_settings_updated_at" BEFORE UPDATE ON "public"."app_settings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_area_cover_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_area_cover_porter_assignments_updated_at" BEFORE UPDATE ON "public"."area_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_buildings_updated_at" BEFORE UPDATE ON "public"."buildings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_default_area_cover_assignments_timestamp" BEFORE UPDATE ON "public"."default_area_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_default_area_cover_porter_assignments_timestamp" BEFORE UPDATE ON "public"."default_area_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_default_service_cover_assignments_timestamp" BEFORE UPDATE ON "public"."default_service_cover_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



CREATE OR REPLACE TRIGGER "update_default_service_cover_porter_assignments_timestamp" BEFORE UPDATE ON "public"."default_service_cover_porter_assignments" FOR EACH ROW EXECUTE FUNCTION "public"."update_modified_column"();



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



ALTER TABLE ONLY "public"."default_area_cover_assignments"
    ADD CONSTRAINT "default_area_cover_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_ass_default_area_cover_assignmen_fkey" FOREIGN KEY ("default_area_cover_assignment_id") REFERENCES "public"."default_area_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_area_cover_porter_assignments"
    ADD CONSTRAINT "default_area_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_service_cover_assignments"
    ADD CONSTRAINT "default_service_cover_assignments_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."support_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter__default_service_cover_assign_fkey" FOREIGN KEY ("default_service_cover_assignment_id") REFERENCES "public"."default_service_cover_assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."default_service_cover_porter_assignments"
    ADD CONSTRAINT "default_service_cover_porter_assignments_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."departments"
    ADD CONSTRAINT "departments_building_id_fkey" FOREIGN KEY ("building_id") REFERENCES "public"."buildings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."porter_absences"
    ADD CONSTRAINT "porter_absences_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



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



CREATE POLICY "Allow authenticated users full access to default area cover ass" ON "public"."default_area_cover_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users full access to default area cover por" ON "public"."default_area_cover_porter_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users full access to default service cover " ON "public"."default_service_cover_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users full access to default service cover " ON "public"."default_service_cover_porter_assignments" TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to manage shift defaults" ON "public"."shift_defaults" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to manage shift tasks" ON "public"."shift_tasks" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to manage shifts" ON "public"."shifts" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to read all shift defaults" ON "public"."shift_defaults" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."copy_defaults_on_shift_creation"() TO "anon";
GRANT ALL ON FUNCTION "public"."copy_defaults_on_shift_creation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."copy_defaults_on_shift_creation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_modified_column"() TO "service_role";



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



GRANT ALL ON TABLE "public"."default_area_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_area_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_area_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."default_area_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_area_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_area_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."default_service_cover_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_service_cover_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_service_cover_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."default_service_cover_porter_assignments" TO "anon";
GRANT ALL ON TABLE "public"."default_service_cover_porter_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."default_service_cover_porter_assignments" TO "service_role";



GRANT ALL ON TABLE "public"."departments" TO "anon";
GRANT ALL ON TABLE "public"."departments" TO "authenticated";
GRANT ALL ON TABLE "public"."departments" TO "service_role";



GRANT ALL ON TABLE "public"."porter_absences" TO "anon";
GRANT ALL ON TABLE "public"."porter_absences" TO "authenticated";
GRANT ALL ON TABLE "public"."porter_absences" TO "service_role";



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
	('22639f07-209d-41e6-b3e3-f569b6c4db96', 'GMT', '24h', '2025-05-24 12:03:15.409004+00', '2025-05-24 12:03:15.198+00'),
	('fa5c9416-2b70-4b81-9f54-7ebaaac411c0', 'GMT', '24h', '2025-05-28 14:07:30.519927+00', '2025-05-28 14:07:27.858+00');


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."buildings" ("id", "name", "address", "created_at", "updated_at", "sort_order") VALUES
	('b4891ac9-bb9c-4c63-977d-038890607b98', 'Harstshead', NULL, '2025-05-22 10:41:06.907057+00', '2025-05-30 10:36:03.190794+00', 0),
	('e85c40e7-6f29-4e22-9787-6ed289c36429', 'Charlesworth Building', NULL, '2025-05-24 12:20:54.129832+00', '2025-05-30 10:36:03.190794+00', 10),
	('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ladysmith Building', '123 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-05-30 10:36:03.190794+00', 20),
	('abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Stores', NULL, '2025-05-29 08:52:06.678532+00', '2025-05-30 10:36:03.190794+00', 30),
	('23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Portland Building', NULL, '2025-05-24 15:33:42.930237+00', '2025-05-30 10:36:03.190794+00', 40),
	('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Werneth House', '200 Science Boulevard', '2025-05-22 10:30:30.870153+00', '2025-05-30 10:36:03.190794+00', 50),
	('d4d0bf79-eb71-477e-9d06-03159039e425', 'New Fountain House', NULL, '2025-05-24 12:20:27.560098+00', '2025-05-30 10:36:03.190794+00', 60),
	('e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Bereavement Centre', NULL, '2025-05-24 15:12:37.764027+00', '2025-05-30 10:36:03.190794+00', 70),
	('69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Unit', NULL, '2025-05-24 15:31:30.919629+00', '2025-05-30 10:36:03.190794+00', 80),
	('e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal Unit', NULL, '2025-05-24 15:34:16.907485+00', '2025-05-30 10:36:03.190794+00', 90),
	('20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', NULL, '2025-05-27 15:49:56.650867+00', '2025-05-30 10:36:03.190794+00', 100);


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."departments" ("id", "building_id", "name", "is_frequent", "created_at", "updated_at", "sort_order") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 41', true, '2025-05-22 10:30:30.870153+00', '2025-05-28 12:25:54.280198+00', 10),
	('1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'A+E (ED)', false, '2025-05-24 15:06:24.428146+00', '2025-05-30 10:34:49.995348+00', 170),
	('2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'NICU', true, '2025-05-24 12:21:01.329031+00', '2025-05-30 10:35:46.86368+00', 0),
	('6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 27', true, '2025-05-24 15:04:56.615271+00', '2025-05-30 10:35:46.86368+00', 10),
	('9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 30 (HCU)', true, '2025-05-24 15:05:26.651408+00', '2025-05-30 10:35:46.86368+00', 30),
	('c24a3784-6a06-469f-a764-49621f2d88d3', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 31', true, '2025-05-24 15:05:37.494475+00', '2025-05-30 10:35:46.86368+00', 40),
	('81c30d93-8712-405c-ac5e-509d48fd9af9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'AMU', true, '2025-05-23 14:37:07.660982+00', '2025-05-30 10:36:46.941754+00', 10),
	('831035d1-93e9-4683-af25-b40c2332b2fe', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'EOU', true, '2025-05-22 10:41:18.749919+00', '2025-05-30 10:36:52.347554+00', 50),
	('8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'IAU', false, '2025-05-24 15:05:46.603744+00', '2025-05-30 10:37:08.411942+00', 140),
	('a8d3be01-4d46-41c1-b304-ab98610847e7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Vasular Studies', true, '2025-05-24 15:06:04.488647+00', '2025-05-30 10:37:13.256208+00', 160),
	('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 40', false, '2025-05-22 10:30:30.870153+00', '2025-05-28 09:40:45.973966+00', 20),
	('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Library', false, '2025-05-22 10:30:30.870153+00', '2025-05-28 09:40:45.973966+00', 30),
	('9056ee14-242b-4208-a87d-fc59d24d442c', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Pathology Lab', false, '2025-05-24 12:20:41.049859+00', '2025-05-28 09:40:45.973966+00', 70),
	('fa9e4d42-8282-42f8-bfd4-87691e20c7ed', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Ward', false, '2025-05-24 15:05:14.044021+00', '2025-05-28 09:40:45.973966+00', 110),
	('6dc82d06-d4d2-4824-9a83-d89b583b7554', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'SDEC', false, '2025-05-24 15:05:53.620867+00', '2025-05-28 09:40:45.973966+00', 150),
	('f9d3bbce-8644-4075-8b80-457777f6d16c', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Ground Floor', false, '2025-05-24 15:06:39.563069+00', '2025-05-28 09:40:45.973966+00', 180),
	('8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Lower Ground Floor', false, '2025-05-24 15:06:52.499906+00', '2025-05-28 09:40:45.973966+00', 190),
	('42c2b3ab-f68d-429c-9675-3c79ff0ed222', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Ultrasound', false, '2025-05-24 15:07:04.431723+00', '2025-05-28 09:40:45.973966+00', 200),
	('35c73844-b511-423e-996c-5328ef21fedd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Clinics A-F', false, '2025-05-24 15:07:14.550747+00', '2025-05-28 09:40:45.973966+00', 210),
	('7295def1-1827-46dc-a443-a7aa7bf85b52', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Yellow Suite', false, '2025-05-24 15:07:27.863388+00', '2025-05-28 09:40:45.973966+00', 220),
	('f7c99832-60d1-42ee-8d35-0620a38f1e5d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Blue Suite', false, '2025-05-24 15:07:36.0704+00', '2025-05-28 09:40:45.973966+00', 230),
	('465893b5-6ab8-4776-bdbd-fd3c608ab966', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Swan Room', false, '2025-05-24 15:07:48.317926+00', '2025-05-28 09:40:45.973966+00', 240),
	('ac2333d2-0b37-4924-a039-478caf702fbd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s O+A', false, '2025-05-24 15:08:31.112268+00', '2025-05-28 09:40:45.973966+00', 260),
	('7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Day Surgery', false, '2025-05-24 15:09:06.573728+00', '2025-05-28 09:40:45.973966+00', 270),
	('4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Endoscopy Unit', false, '2025-05-24 15:09:18.185641+00', '2025-05-28 09:40:45.973966+00', 280),
	('f7525622-cd84-4c8c-94bf-b0428008b9c3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Frailty', false, '2025-05-24 15:10:12.266212+00', '2025-05-28 09:40:45.973966+00', 300),
	('36e599c5-89b2-4d50-b7df-47d5d1959ca4', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Surgical Hub', false, '2025-05-24 15:10:26.062318+00', '2025-05-28 09:40:45.973966+00', 310),
	('19b02bca-1dc6-4d00-b04d-a7e141a04870', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Plaster Room', false, '2025-05-24 15:10:32.921441+00', '2025-05-28 09:40:45.973966+00', 320),
	('76753b4b-ae1e-4477-a042-8deaab558e7b', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Discharge Lounge', false, '2025-05-24 15:11:40.525042+00', '2025-05-28 09:40:45.973966+00', 340),
	('0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 44', false, '2025-05-24 15:11:55.713923+00', '2025-05-28 09:40:45.973966+00', 360),
	('569e9211-d394-4e93-ba3e-34ad20d98af4', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 45', false, '2025-05-24 15:12:01.01766+00', '2025-05-28 09:40:45.973966+00', 370),
	('0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 46', false, '2025-05-24 15:12:07.981632+00', '2025-05-28 09:40:45.973966+00', 380),
	('99d8db21-2c14-4f8f-8e54-54fc81004997', 'e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Rose Cottage', false, '2025-05-24 15:12:49.940045+00', '2025-05-28 09:40:45.973966+00', 390),
	('87a21a43-fe29-448f-9c08-b4d94226ad3f', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Infection Control', false, '2025-05-24 15:13:12.738948+00', '2025-05-28 09:40:45.973966+00', 400),
	('60c6f384-09d7-4ec8-bc90-b72fe1d82af9', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Switch', false, '2025-05-24 15:13:28.133871+00', '2025-05-28 09:40:45.973966+00', 410),
	('c06cd3c4-8993-4e7b-b198-a7fda4ede658', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Estates Management', false, '2025-05-24 15:13:37.481503+00', '2025-05-28 09:40:45.973966+00', 420),
	('a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'CDS (Acorn Birth Centre)', false, '2025-05-24 15:14:21.560252+00', '2025-05-28 09:40:45.973966+00', 430),
	('23199491-fe75-4c33-9cc8-1c86070cf0d1', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Triage', false, '2025-05-24 15:15:20.429518+00', '2025-05-28 09:40:45.973966+00', 450),
	('c0a07de6-b201-441b-a1fb-2b2ae9a95ac1', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Reception', false, '2025-05-24 15:16:21.942089+00', '2025-05-28 09:40:45.973966+00', 460),
	('bcb9ab4c-88c9-4d90-8b10-d97216de49ed', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Transfusion', false, '2025-05-24 15:20:33.127806+00', '2025-05-28 09:40:45.973966+00', 470),
	('969a27a7-f5e5-4c23-b018-128aa2000b97', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Bed Store', false, '2025-05-24 15:21:21.166917+00', '2025-05-28 09:40:45.973966+00', 480),
	('5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Mattress Store', false, '2025-05-24 15:21:31.144781+00', '2025-05-28 09:40:45.973966+00', 490),
	('9dae2f86-2058-4c9c-a428-76f5648553d3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'North Theatres', false, '2025-05-24 15:24:43.214387+00', '2025-05-28 09:40:45.973966+00', 500),
	('07e2b454-88ee-4d6a-9d75-a6ffa39bd241', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'South Theatres', false, '2025-05-24 15:24:51.854136+00', '2025-05-28 09:40:45.973966+00', 510),
	('d82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'MRI', false, '2025-05-24 15:25:16.973586+00', '2025-05-28 09:40:45.973966+00', 530),
	('df3d8d2a-dee5-4a21-a362-401236a2a1cb', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Pharmacy', false, '2025-05-24 15:30:28.871857+00', '2025-05-28 09:40:45.973966+00', 540),
	('943915e4-6818-4890-b395-a8272718eaf7', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford One', false, '2025-05-24 15:31:43.707094+00', '2025-05-28 09:40:45.973966+00', 550),
	('0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Two', false, '2025-05-24 15:31:53.020936+00', '2025-05-28 09:40:45.973966+00', 560),
	('1cac53b0-f370-4a13-95ca-f4cfd85dd197', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Ground', false, '2025-05-24 15:32:00.795352+00', '2025-05-28 09:40:45.973966+00', 570),
	('55f54692-d1ee-4047-bace-ff31744d2bc7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'FM Corridor', false, '2025-05-24 15:32:36.1272+00', '2025-05-28 09:40:45.973966+00', 580),
	('270df887-a13f-4004-a58d-9cec125b8da1', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Kitchens', false, '2025-05-24 15:32:43.567186+00', '2025-05-28 09:40:45.973966+00', 590),
	('06582332-0637-4d1a-b86e-876afe0bdc98', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Laundry', false, '2025-05-24 15:33:51.477397+00', '2025-05-28 09:40:45.973966+00', 600),
	('bf03ffcf-98d7-440e-adc1-5081e161c42d', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'I.T.', false, '2025-05-24 15:33:57.806509+00', '2025-05-28 09:40:45.973966+00', 610),
	('2368699a-6de0-45a9-ae25-dad26160cada', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Porters Lodge', false, '2025-05-24 15:34:07.683358+00', '2025-05-28 09:40:45.973966+00', 620),
	('ccb6bf8f-275c-4d24-8907-09b97cbe0eea', 'e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal', false, '2025-05-24 15:34:28.590837+00', '2025-05-28 09:40:45.973966+00', 630),
	('4c0821a2-dba8-48fe-9b8d-1c1ed6f8edea', '20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', false, '2025-05-27 15:50:07.946454+00', '2025-05-28 09:40:45.973966+00', 640),
	('1ae5c936-b74c-453e-a614-42b983416e40', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 43', true, '2025-05-24 15:11:49.971178+00', '2025-05-28 11:48:51.366161+00', 0),
	('3aa17398-7823-45ae-b76c-9b30d8509ce1', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 42', false, '2025-05-24 15:11:16.394196+00', '2025-05-28 12:25:57.780742+00', 10),
	('5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'CT Department', false, '2025-05-24 15:25:11.218374+00', '2025-05-28 15:11:27.305929+00', 520),
	('acb46743-a8c8-4cf5-bc85-4b9480f1862e', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Stores', false, '2025-05-29 08:52:15.626457+00', '2025-05-29 08:52:15.626457+00', 0),
	('571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Womens Health', true, '2025-05-24 15:14:53.225063+00', '2025-05-30 10:35:46.86368+00', 20),
	('dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s Unit', false, '2025-05-24 15:08:15.838239+00', '2025-05-30 10:36:42.972929+00', 0),
	('c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'POU', true, '2025-05-24 15:09:37.760662+00', '2025-05-30 10:37:00.354699+00', 290);


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."staff" ("id", "first_name", "last_name", "role", "created_at", "updated_at", "department_id", "porter_type", "availability_pattern", "contracted_hours_start", "contracted_hours_end") VALUES
	('4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'Martin', 'Smith', 'supervisor', '2025-05-22 16:38:43.142566+00', '2025-05-22 16:38:43.142566+00', NULL, 'shift', NULL, NULL, NULL),
	('b88b49d1-c394-491e-aaa7-cc196250f0e4', 'Martin', 'Fearon', 'supervisor', '2025-05-22 12:36:39.488519+00', '2025-05-22 16:38:53.581199+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'shift', NULL, NULL, NULL),
	('358aa759-e11e-40b0-b886-37481c5eb6c0', 'Chris', 'Chrombie', 'supervisor', '2025-05-22 16:39:03.319212+00', '2025-05-22 16:39:03.319212+00', NULL, 'shift', NULL, NULL, NULL),
	('a9d969e3-d449-4005-a679-f63be07c6872', 'Luke', 'Clements', 'supervisor', '2025-05-22 16:39:16.282662+00', '2025-05-22 16:39:16.282662+00', NULL, 'shift', NULL, NULL, NULL),
	('6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', 'KG', 'Porter', 'porter', '2025-05-28 15:38:38.608871+00', '2025-05-30 16:20:37.92001+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('e9cf3a23-c94a-409b-aa71-d42602e54068', 'MP', 'Porter', 'porter', '2025-05-28 15:38:29.329131+00', '2025-05-30 16:21:01.802578+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('f304fa99-8e00-48d0-a616-d156b0f7484d', 'CW', 'Porter', 'porter', '2025-05-24 15:29:00.080381+00', '2025-05-30 17:10:15.855945+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('4fb21c6f-2f5b-4f6e-b727-239a3391092a', 'EA', 'Porter', 'porter', '2025-05-24 15:29:10.541023+00', '2025-05-30 17:10:43.050862+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('394d8660-7946-4b31-87c9-b60f7e1bc294', 'GB', 'Porter', 'porter', '2025-05-23 14:36:44.275665+00', '2025-05-30 17:11:04.72929+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('12055968-78d3-4404-a05f-10e039217936', 'MB', 'Porter', 'porter', '2025-05-24 15:35:19.897285+00', '2025-05-30 17:13:13.113785+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('050fa6e6-477b-4f83-aae4-3e13c954ca6a', 'Xray', 'Porter 1', 'porter', '2025-05-28 15:40:45.206052+00', '2025-05-28 15:40:45.206052+00', NULL, 'shift', NULL, NULL, NULL),
	('cb50a5b2-3812-4688-b1f6-ccf0ab7626b6', 'Xray', 'Porter 2', 'porter', '2025-05-28 15:40:56.522945+00', '2025-05-28 15:40:56.522945+00', NULL, 'shift', NULL, NULL, NULL),
	('473eeca1-e8ca-49a7-b2f6-5870dc254dcc', 'No', 'Supervisor', 'supervisor', '2025-05-29 12:56:45.696149+00', '2025-05-29 12:56:45.696149+00', NULL, 'shift', NULL, NULL, NULL),
	('80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', 'RS', 'Porter', 'porter', '2025-05-28 15:38:06.309697+00', '2025-05-30 16:21:29.758058+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('c3052ff8-8339-4e02-b4ed-efee9365e7c2', 'MC', 'Porter', 'porter', '2025-05-28 15:37:56.707711+00', '2025-05-30 16:21:53.673996+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('8b3b3e97-ea54-4c40-884b-04d3d24dbe23', 'JM', 'Porter', 'porter', '2025-05-24 15:46:43.723804+00', '2025-05-30 17:13:40.748857+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('e55b1013-7e79-4e38-913e-c53de591f85c', 'LR', 'Porter', 'porter', '2025-05-24 15:47:03.70938+00', '2025-05-30 17:13:59.97549+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('69766d05-49d7-4e7c-8734-e3dc8949bf91', 'MD', 'Porter', 'porter', '2025-05-24 15:47:22.720752+00', '2025-05-30 17:15:12.217517+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'IS', 'Porter', 'porter', '2025-05-22 15:14:47.797324+00', '2025-05-30 17:15:38.338145+00', NULL, 'shift', 'Weekdays - Days', '07:30:00', '15:30:00'),
	('c162858c-9815-43e3-9bcb-0c709bd8eef0', 'SC', 'Porter', 'porter', '2025-05-28 15:39:52.203155+00', '2025-05-31 12:04:48.961386+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('1a21db6c-9a35-48ca-a3b0-06284bec8beb', 'AJ', 'Porter', 'porter', '2025-05-28 15:39:12.414354+00', '2025-05-30 16:22:30.530571+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('04947318-f8a7-4eea-8044-5219c5e907fc', 'CB', 'Porter', 'porter', '2025-05-28 15:36:24.156976+00', '2025-05-31 09:20:58.647194+00', NULL, 'shift', 'Weekends - Days', '11:00:00', '19:00:00'),
	('c965e4e3-e132-43f0-94ce-1b41d33a9f05', 'CR', 'Porter', 'porter', '2025-05-28 15:36:13.899635+00', '2025-05-31 09:21:51.335781+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('ecc67de0-fecc-4c93-b9da-445c3cef4ea4', 'LY', 'Porter', 'porter', '2025-05-24 15:28:41.635621+00', '2025-05-31 12:05:19.000564+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', 'DM', 'Porter 1', 'porter', '2025-05-28 15:40:00.100404+00', '2025-05-30 16:19:39.09899+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('2ef290c6-6c61-4d37-be45-d08ae6afc097', 'DM', 'Porter 2', 'porter', '2025-05-28 15:40:14.777056+00', '2025-05-30 16:20:03.887273+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('83fdb588-e638-47ae-b726-51f83a4378c7', 'MS', 'Porter', 'porter', '2025-05-28 15:39:06.096334+00', '2025-05-30 16:23:02.826204+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('4377dd38-cf15-4de2-8347-0461ba6afff5', 'SH', 'Porter', 'porter', '2025-05-28 15:36:45.727912+00', '2025-05-30 16:23:48.277704+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', 'SM', 'Porter', 'porter', '2025-05-28 15:36:52.317877+00', '2025-05-30 16:24:12.341778+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('56d5a952-a958-41c5-aa28-bd42e06720c8', 'MH', 'Porter', 'porter', '2025-05-28 15:37:14.70567+00', '2025-05-30 16:24:43.554717+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('b96a6ffa-6f54-4eab-a1c8-5c65dc7223da', 'MW', 'Porter', 'porter', '2025-05-28 15:37:22.975093+00', '2025-05-30 16:25:18.624641+00', NULL, 'shift', 'Weekdays - Days', '06:00:00', '14:00:00'),
	('296edb55-91eb-4d73-aa43-54840cbbf20c', 'AB', 'Porter', 'porter', '2025-05-28 15:37:34.781762+00', '2025-05-30 16:25:58.74326+00', NULL, 'shift', 'Weekdays - Days', '14:00:00', '22:00:00'),
	('1aaab277-ecf2-40dd-a764-eaaf8af7615b', 'At', 'Porter', 'porter', '2025-05-28 15:36:02.205704+00', '2025-05-31 09:22:48.757543+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'JR', 'Porter 2', 'porter', '2025-05-24 15:28:21.287841+00', '2025-05-31 12:06:15.759371+00', NULL, 'relief', 'Weekdays - Days', '14:00:00', '22:00:00'),
	('4e87f01b-5196-47c4-b424-4cfdbe7fb385', 'SC', 'Porter', 'porter', '2025-05-24 15:47:12.658077+00', '2025-05-30 16:28:12.48615+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('8eaa9194-b164-4cb4-a15c-956299ff28c5', 'TB', 'Porter', 'porter', '2025-05-24 15:46:56.110419+00', '2025-05-30 16:28:35.874646+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('786d6d23-69b9-433e-92ed-938806cb10a8', 'LB', 'Porter', 'porter', '2025-05-23 14:15:42.030594+00', '2025-05-31 12:06:29.729689+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'MH', 'Porter 2', 'porter', '2025-05-22 15:14:27.136064+00', '2025-05-30 16:29:52.389588+00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('2e74429e-2aab-4bed-a979-6ccbdef74596', 'JR', 'Porter', 'porter', '2025-05-24 15:27:50.974195+00', '2025-05-30 16:30:18.953012+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', 'LS', 'Porter', 'porter', '2025-05-24 15:28:02.842334+00', '2025-05-30 16:59:08.457239+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('bf79faf6-fb3e-4780-841e-63a4a67a5b77', 'NB', 'Porter', 'porter', '2025-05-24 15:28:15.192437+00', '2025-05-30 17:08:00.606828+00', NULL, 'shift', 'Weekdays - Days', '13:00:00', '23:00:00'),
	('7cc268aa-cb72-4320-ba8d-72f77b77dda6', 'DP', 'Porter', 'porter', '2025-05-31 09:36:39.240883+00', '2025-05-31 12:08:25.0057+00', NULL, 'relief', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('7c20aec3-bf78-4ef9-b35e-429e41ac739b', 'KS', 'Porter', 'porter', '2025-05-24 15:28:35.013201+00', '2025-05-30 17:09:23.036433+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('2524b1c5-45e1-4f15-bf3b-984354f22cdc', 'PM', 'Porter', 'porter', '2025-05-24 15:28:50.433536+00', '2025-05-30 17:09:45.582369+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('172b28c4-ec0d-4f5c-a859-ff8299ff6243', 'SS', 'Porter', 'porter', '2025-05-31 09:23:33.02904+00', '2025-05-31 09:23:33.02904+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('b4bcc3bc-729a-49fe-bf6e-1c30fcac37b3', 'JF', 'Porter', 'porter', '2025-05-31 09:24:06.944074+00', '2025-05-31 09:24:06.944074+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('00e0ca67-f415-45ce-9b11-c3260e9cd58e', 'SB', 'Porter', 'porter', '2025-05-31 09:24:52.480925+00', '2025-05-31 09:24:52.480925+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('63f5c89b-661d-40e5-a810-7fba772d4dc5', 'KB', 'Porter', 'porter', '2025-05-31 09:30:45.461948+00', '2025-05-31 09:30:45.461948+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('d34fa6f7-8d2d-4e20-abda-a77c11554254', 'DF', 'Porter', 'porter', '2025-05-31 09:31:17.530822+00', '2025-05-31 09:31:17.530822+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('5bfb19a8-f295-4e17-b63d-01166fd22acf', 'BC', 'Porter', 'porter', '2025-05-31 09:31:35.719888+00', '2025-05-31 09:31:35.719888+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('4b49d53b-2473-4cc9-9b08-221a6548a93d', 'JM', 'Porter', 'porter', '2025-05-31 09:31:58.967695+00', '2025-05-31 09:31:58.967695+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('af42f57f-1437-4320-b1a2-2b0051948de3', 'AK', 'Porter', 'porter', '2025-05-31 09:32:32.204314+00', '2025-05-31 09:32:32.204314+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('7884c45a-823f-48c9-a4d4-fd2ad426f144', 'SF', 'Porter', 'porter', '2025-05-31 09:35:54.501508+00', '2025-05-31 09:35:54.501508+00', NULL, 'shift', 'Weekdays - Days', '06:00:00', '14:00:00'),
	('4a25cc37-bc1f-4a94-a053-e348412a2432', 'AH', 'Porter', 'porter', '2025-05-31 09:38:15.586949+00', '2025-05-31 09:38:15.586949+00', NULL, 'shift', '4 on 4 off - Days', '13:00:00', '01:00:00'),
	('6c6184fe-7e99-4fc0-a906-ace0a021f160', 'GM', 'Porter', 'porter', '2025-05-31 09:38:54.952643+00', '2025-05-31 09:38:54.952643+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('3316eda6-d5f5-445f-8721-b8c42e18d89c', 'AC', 'Porter', 'porter', '2025-05-31 09:39:31.25173+00', '2025-05-31 09:39:31.25173+00', NULL, 'shift', 'Weekdays - Days', '14:00:00', '01:00:00'),
	('78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', 'MK', 'Porter', 'porter', '2025-05-24 15:28:08.999647+00', '2025-05-31 12:05:14.813613+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('aeac1145-0b87-403a-81db-72b516a9fe15', 'DK', 'Porter', 'porter', '2025-05-31 09:42:05.947895+00', '2025-05-31 09:42:05.947895+00', NULL, 'shift', 'Weekends - Days', '08:00:00', '20:00:00'),
	('c30cc891-1722-404f-9b84-14ffcee8d93f', 'SL', 'Porter', 'porter', '2025-05-31 09:44:38.837174+00', '2025-05-31 09:44:38.837174+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('7baf82c3-c592-43fa-aac0-b53fbd8e9a1d', 'SR', 'Porter', 'porter', '2025-05-31 11:41:00.64654+00', '2025-05-31 11:41:00.64654+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('0655269c-b297-42e7-bdec-afb55cdee4d2', 'ML', 'Porter', 'porter', '2025-05-31 11:42:20.747495+00', '2025-05-31 11:42:20.747495+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('74da0ff0-44aa-4fd5-a464-d25e45bea636', 'JG', 'Porter', 'porter', '2025-05-31 11:43:39.963596+00', '2025-05-31 11:43:39.963596+00', NULL, 'shift', 'Weekdays - Days', '08:30:00', '16:30:00'),
	('0689dc61-6dcd-413d-a9f8-579fdc716757', 'EC', 'Porter', 'porter', '2025-05-31 11:50:01.961067+00', '2025-05-31 11:50:01.961067+00', NULL, 'shift', 'Weekdays - Days', '10:00:00', '18:00:00'),
	('df3f3a6d-23b5-4970-9ae0-47d458b84dd3', 'PH', 'Porter', 'porter', '2025-05-31 11:50:26.154544+00', '2025-05-31 11:50:26.154544+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('534e6bda-2978-47cd-aacc-f1bd3f94e981', 'KT', 'Porter', 'porter', '2025-05-31 11:50:51.022783+00', '2025-05-31 11:50:51.022783+00', NULL, 'shift', 'Weekdays - Days', '10:00:00', '18:00:00'),
	('8daf3b6b-4e59-4445-ac27-397d1bc7854d', 'CH', 'Porter', 'porter', '2025-05-31 11:52:25.441626+00', '2025-05-31 11:52:25.441626+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('c3579d99-b97e-4019-b37a-f63515fe3ca4', 'PB', 'Porter', 'porter', '2025-05-31 11:52:53.118104+00', '2025-05-31 11:52:53.118104+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', 'RF', 'Porter', 'porter', '2025-05-31 11:53:07.6934+00', '2025-05-31 11:53:07.6934+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('ac5427be-ea01-4f42-9c46-17e2f089dee8', 'AG', 'Porter', 'porter', '2025-05-31 11:53:20.904075+00', '2025-05-31 11:53:20.904075+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('7a905342-f7d6-4105-b56f-d922e86dbbd9', 'NB', 'Porter', 'porter', '2025-05-31 11:53:50.689917+00', '2025-05-31 11:53:50.689917+00', NULL, 'shift', 'Weekdays - Days', '08:30:00', '16:30:00'),
	('2fe13155-0425-4634-b42a-04380ff73ad1', 'PF', 'Porter', 'porter', '2025-05-31 11:54:42.540751+00', '2025-05-31 11:54:42.540751+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('ccac560c-a3ad-4517-895d-86870e9ad00a', 'AF', 'Porter', 'porter', '2025-05-31 12:05:54.898527+00', '2025-05-31 12:05:54.898527+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('6e772f6a-e4e8-422a-b21b-ff677b625471', 'SO', 'Porter', 'porter', '2025-05-31 12:07:12.641402+00', '2025-05-31 12:07:12.641402+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('a55d23b5-154f-425b-a0b3-11d5e3ef5ffd', 'MR', 'Porter', 'porter', '2025-05-31 12:09:18.007059+00', '2025-05-31 12:09:18.007059+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('1f1e61c3-848c-441c-8b89-8a85e16285df', 'DS', 'Porter', 'porter', '2025-05-31 12:09:48.190182+00', '2025-05-31 12:09:48.190182+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('b30280c2-aecc-4953-a1df-5f703bce4772', 'JN', 'Porter', 'porter', '2025-06-02 17:25:09.547001+00', '2025-06-02 17:25:09.547001+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00');


--
-- Data for Name: area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_assignments" ("id", "department_id", "porter_id", "start_time", "end_time", "color", "created_at", "updated_at", "shift_type") VALUES
	('1d4a326e-8401-4e31-b1ec-fa810b68fd1a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '20:00:00', '08:00:00', '#4285F4', '2025-05-24 15:42:29.23697+00', '2025-05-26 09:05:32.036362+00', 'week_night'),
	('06213b7c-812e-4f48-a79d-ecbc9a87d30a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '08:00:00', '20:00:00', '#4285F4', '2025-05-24 15:45:03.686512+00', '2025-05-26 09:05:42.619325+00', 'weekend_day'),
	('2100396b-f96d-4a7c-9d1b-006775df4ef7', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:44:23.448158+00', '2025-05-26 09:05:52.579036+00', 'weekend_night'),
	('a2787626-bc01-411b-a2ca-a50d2c63ced6', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', NULL, '08:00:00', '20:00:00', '#4285F4', '2025-05-24 15:30:45.762708+00', '2025-05-26 10:32:42.81672+00', 'week_day'),
	('4030ddba-717e-498d-92fc-cf401ef4d908', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-24 15:40:52.51208+00', '2025-05-24 15:40:52.51208+00', 'week_day'),
	('8c1d80d9-68f3-4bc2-a578-5707de26e00f', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', NULL, '20:00:00', '04:00:00', '#4285F4', '2025-05-25 09:56:41.356955+00', '2025-05-25 09:56:41.356955+00', 'week_night');


--
-- Data for Name: area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."area_cover_porter_assignments" ("id", "area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('6da09732-7edb-498b-aa5b-5c006f9b3297', 'a2787626-bc01-411b-a2ca-a50d2c63ced6', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-26 10:32:42.903703+00', '2025-05-26 10:32:42.903703+00');


--
-- Data for Name: default_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_assignments" ("id", "department_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('55a9e1d1-b177-4fc8-ba8d-a1483bd58e40', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'week_day', '11:00:00', '18:00:00', '#e22400', '2025-05-28 15:05:10.786766+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('84a7eb2b-66ad-4883-a6ef-e78bedff694a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:29.515957+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2f7b79ab-e3fd-4745-9095-633bc97a05cc', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:47.240244+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('62d6ae7f-b3ef-4bd0-ad5a-c4a0ab46c5fa', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:13:50.992166+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('de8f136e-deeb-494b-bae9-54cf7a4ea5bf', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:14:15.321389+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ed182065-4e96-40cb-9b41-96f7cdebb907', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:20:32.081824+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9ccff924-1281-42ac-b712-7989bfe50c6d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'weekend_day', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:21:05.371703+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4b07ffe6-9df3-4e93-ba02-ecd8607c65d3', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'weekend_night', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 15:21:24.017899+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('73fee5fd-ec48-4e53-9a6a-bb2cdad86311', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'week_day', '08:00:00', '20:00:00', '#d357fe', '2025-05-28 15:13:17.977154+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3a2ff90b-5523-4f5f-848d-3d8989c81981', 'f9d3bbce-8644-4075-8b80-457777f6d16c', 'week_day', '08:00:00', '17:00:00', '#4285F4', '2025-05-28 15:11:59.336598+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5aa10d36-c060-4ca1-97a6-3dbd2854ab3d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:12:06.807373+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d60ea4d0-7c69-412c-9dd1-aad01645e1dc', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'week_day', '08:00:00', '20:00:00', '#4e7a27', '2025-05-28 15:12:39.489353+00', '2025-06-03 15:05:53.065791+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('d71c6999-f5ca-4108-a2e0-21c4afc008f5', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_day', '08:00:00', '22:00:00', '#f443b3', '2025-05-28 15:07:17.30595+00', '2025-06-03 16:19:53.196765+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: default_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_porter_assignments" ("id", "default_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('62d587a8-3897-45bc-98b4-71532ddfd26b', '3a2ff90b-5523-4f5f-848d-3d8989c81981', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-05-31 15:25:00.501678+00', '2025-05-31 15:25:00.501678+00'),
	('3f7c91e8-c24c-4af2-9515-7380f07e5ff1', '3a2ff90b-5523-4f5f-848d-3d8989c81981', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-05-31 15:25:00.5513+00', '2025-05-31 15:25:00.5513+00'),
	('dc65a01c-287b-4145-84a6-331237a72f3a', '5aa10d36-c060-4ca1-97a6-3dbd2854ab3d', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-05-31 15:26:32.100352+00', '2025-05-31 15:26:32.100352+00'),
	('eccbf4fc-ffaf-42c6-812b-beaf1d91173b', '5aa10d36-c060-4ca1-97a6-3dbd2854ab3d', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-05-31 15:26:32.16221+00', '2025-05-31 15:26:32.16221+00'),
	('0b2607be-1a5c-41d8-92db-f06595a0868a', 'd60ea4d0-7c69-412c-9dd1-aad01645e1dc', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-05-31 15:30:09.094954+00', '2025-06-03 15:05:53.140803+00'),
	('eb3d4131-0bf3-4c12-9998-93f0a6238b32', 'd60ea4d0-7c69-412c-9dd1-aad01645e1dc', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-05-31 15:30:09.146339+00', '2025-06-03 15:05:53.22486+00'),
	('98f3579a-6cc4-4c21-8cf3-076f1be56d6e', 'd71c6999-f5ca-4108-a2e0-21c4afc008f5', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-05-31 15:33:24.32966+00', '2025-06-03 16:19:53.284229+00'),
	('5f055cba-c4df-48f2-9298-3896a360e4a2', 'd71c6999-f5ca-4108-a2e0-21c4afc008f5', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-01 18:40:20.05806+00', '2025-06-03 16:19:53.373749+00');


--
-- Data for Name: support_services; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_services" ("id", "name", "description", "is_active", "created_at", "updated_at") VALUES
	('30c5c045-a442-4ec8-b285-c7bc010f4d83', 'Laundry', 'Porter support for laundry services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ce940139-6ae7-49de-a62a-0d6ba9397928', 'Post', 'Internal mail and document delivery', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('0b5c7062-1285-4427-8387-b1b4e14eedc9', 'Pharmacy', 'Medication delivery service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'District Drivers', 'External transport services', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('7cfa1ddf-61b0-489e-ad23-b924cf995419', 'Adhoc', 'Miscellaneous tasks requiring porter assistance', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('26c0891b-56c0-4346-8d53-de906aaa64c2', 'Medical Records', 'Patient records transport service', true, '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00'),
	('2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'External Waste', NULL, true, '2025-05-28 15:08:35.337525+00', '2025-05-28 15:08:35.337525+00');


--
-- Data for Name: default_service_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_assignments" ("id", "service_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('ce4b641d-619d-4c1b-8c68-d9d850306492', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:14:07.575453+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '26c0891b-56c0-4346-8d53-de906aaa64c2', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:46.235606+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('557671ae-71a7-41f5-bbf7-7d74413e7c9a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:40.45798+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', 'ce940139-6ae7-49de-a62a-0d6ba9397928', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:33.377391+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'week_day', '08:30:00', '17:00:00', '#4285F4', '2025-05-28 15:07:57.826093+00', '2025-06-01 18:54:01.298525+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'week_day', '07:00:00', '15:00:00', '#c8a76f', '2025-05-28 15:08:50.364355+00', '2025-06-02 17:19:07.627643+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('aa1a61d1-e538-415a-a89d-9f568fc92adb', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:05:23.573715+00', '2025-06-02 17:21:42.130912+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '7cfa1ddf-61b0-489e-ad23-b924cf995419', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:07:52.088351+00', '2025-06-02 17:22:13.751488+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: default_service_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_porter_assignments" ("id", "default_service_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('8317bd19-3ac9-4b0e-a200-7f8d201fa630', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-01 18:54:01.502989+00', '2025-06-01 18:54:01.502989+00'),
	('6dc87b69-0871-447f-a0c0-75cac448c449', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-01 18:54:01.54246+00', '2025-06-01 18:54:01.54246+00'),
	('0c25f6c0-19f1-4288-97cf-9b28212a9e0a', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-01 18:54:01.589009+00', '2025-06-01 18:54:01.589009+00'),
	('4578c334-21c4-4427-9569-cd251016820e', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-01 18:54:01.632847+00', '2025-06-01 18:54:01.632847+00'),
	('a8f08037-c45c-4692-bc79-171d7182f8f7', '57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-02 17:19:07.709693+00', '2025-06-02 17:19:07.709693+00'),
	('f3fe847c-e319-4ea8-a4b1-ea0dae937da0', '57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-02 17:19:07.771004+00', '2025-06-02 17:19:07.771004+00'),
	('44d34895-d3e5-4a87-b845-67f8aff12f37', '8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-02 17:22:13.804891+00', '2025-06-02 17:22:13.804891+00');


--
-- Data for Name: porter_absences; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."porter_absences" ("id", "porter_id", "absence_type", "start_date", "end_date", "created_at", "updated_at", "notes") VALUES
	('39946668-fb64-46dc-ade9-3e4e63482372', '7884c45a-823f-48c9-a4d4-fd2ad426f144', 'illness', '2025-06-03', '2025-06-10', '2025-06-03 15:55:02.824141+00', '2025-06-03 15:55:02.824141+00', NULL),
	('4fb85cec-3dd5-445f-a301-21e82d5867dc', '2e74429e-2aab-4bed-a979-6ccbdef74596', 'illness', '2025-06-03', '2025-06-05', '2025-06-03 16:19:50.491773+00', '2025-06-03 16:19:50.491773+00', 'Test');


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shifts" ("id", "supervisor_id", "shift_type", "start_time", "end_time", "is_active", "created_at", "updated_at") VALUES
	('c0c4074f-a621-456e-b1dc-1fa598ee2a72', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-29 17:32:16+00', '2025-05-29 17:39:18.309+00', false, '2025-05-29 17:32:16.33093+00', '2025-05-29 17:39:18.548314+00'),
	('be379e15-5712-454f-9c1a-e429358828ec', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-28 08:25:42.508+00', '2025-05-28 13:50:17.284+00', false, '2025-05-28 08:54:44.361316+00', '2025-05-28 13:50:17.545048+00'),
	('54d0bbe8-6cb1-461e-99bb-2d746affa629', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-29 17:59:00+00', '2025-05-30 09:01:04.373+00', false, '2025-05-29 17:59:00.827285+00', '2025-05-30 09:01:04.545822+00'),
	('252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'week_day', '2025-05-29 17:11:49+00', '2025-05-30 09:01:12.808+00', false, '2025-05-29 17:11:50.246091+00', '2025-05-30 09:01:12.973571+00'),
	('9bc33d1c-2914-454c-bafc-e23374cc170b', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-05-29 14:49:42+00', '2025-05-30 09:01:17.119+00', false, '2025-05-29 14:49:43.084909+00', '2025-05-30 09:01:17.267708+00'),
	('f6e5f57f-23d5-449e-825b-0bad71119102', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-29 14:22:15+00', '2025-05-30 09:01:21.462+00', false, '2025-05-29 14:22:16.150917+00', '2025-05-30 09:01:21.617455+00'),
	('73492413-331f-4373-94ec-20735ee40dc9', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_night', '2025-05-30 17:35:40+00', '2025-05-30 09:01:25.589+00', false, '2025-05-29 17:35:40.559675+00', '2025-05-30 09:01:25.740706+00'),
	('5980a43c-90e5-4721-92f9-d4f6ee516614', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-05-30 11:13:19+00', '2025-05-31 16:54:09.926+00', false, '2025-05-30 11:13:19.855024+00', '2025-05-31 16:54:10.027817+00'),
	('485da1ff-6aba-4442-97c9-de053be8b587', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-05-30 09:01:33+00', '2025-05-31 16:54:14.788+00', false, '2025-05-30 09:01:33.595623+00', '2025-05-31 16:54:14.891835+00'),
	('aceab786-878c-4e03-8933-2351d19e6ee6', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-05-31 16:54:19+00', '2025-05-31 16:55:27.256+00', false, '2025-05-31 16:54:19.752666+00', '2025-05-31 16:55:27.382525+00'),
	('19ee13f3-d97b-45d6-8716-1243ad8ca120', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-02 16:55:37+00', '2025-05-31 18:29:10.493+00', false, '2025-05-31 16:55:37.384983+00', '2025-05-31 18:29:10.592783+00'),
	('cd388712-a45d-4584-a902-c168831a9e34', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'weekend_day', '2025-05-31 18:29:16+00', '2025-05-31 18:29:26.967+00', false, '2025-05-31 18:29:16.258854+00', '2025-05-31 18:29:27.051657+00'),
	('cd7a5899-34e6-4616-8450-0ed8082a236e', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-02 18:29:45+00', '2025-06-01 14:51:15.477+00', false, '2025-05-31 18:29:45.143316+00', '2025-06-01 14:51:15.882322+00'),
	('1d0d0a5a-fbee-4c8e-a3cf-78c4eb1a003c', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'weekend_day', '2025-06-01 14:51:20+00', '2025-06-01 14:51:28.732+00', false, '2025-06-01 14:51:20.424382+00', '2025-06-01 14:51:29.131246+00'),
	('d442b266-e0fe-4b55-a143-3ef42a9bce28', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-02 14:51:40+00', '2025-06-01 15:19:04.043+00', false, '2025-06-01 14:51:41.189307+00', '2025-06-01 15:19:04.601708+00'),
	('781a97d0-29bd-4e8b-8494-dca63156c45c', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-03 15:19:11+00', '2025-06-02 17:15:39.899+00', false, '2025-06-01 15:19:12.249823+00', '2025-06-02 17:15:40.18159+00'),
	('cc523e6c-087a-4456-8ebc-e84d734d0d16', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-06-03 14:39:48+00', '2025-06-03 15:00:34.608+00', false, '2025-06-03 14:39:48.417602+00', '2025-06-03 15:00:34.777622+00'),
	('5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-02 17:15:44+00', '2025-06-03 15:00:39.108+00', false, '2025-06-02 17:15:44.464231+00', '2025-06-03 15:00:39.237913+00'),
	('c72955ef-b280-4ce2-8df5-cb40b2b73a00', '473eeca1-e8ca-49a7-b2f6-5870dc254dcc', 'week_day', '2025-06-03 15:06:00+00', '2025-06-03 15:06:11.836+00', false, '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:11.970019+00'),
	('3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-03 15:00:50+00', '2025-06-03 15:06:15.887+00', false, '2025-06-03 15:00:50.716958+00', '2025-06-03 15:06:16.023046+00'),
	('d357c573-8c18-42d0-a8cf-27f326454959', 'a9d969e3-d449-4005-a679-f63be07c6872', 'week_day', '2025-06-03 15:01:43+00', '2025-06-03 15:06:19.655+00', false, '2025-06-03 15:01:43.680997+00', '2025-06-03 15:06:19.799554+00'),
	('43f0073b-ab8d-4ed6-af91-4cc58492637d', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-03 15:05:25+00', '2025-06-03 15:06:24.564+00', false, '2025-06-03 15:05:26.002298+00', '2025-06-03 15:06:24.700466+00'),
	('2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-03 15:06:41+00', '2025-06-03 16:20:07.971+00', false, '2025-06-03 15:06:42.096088+00', '2025-06-03 16:20:08.145833+00'),
	('a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-06-03 15:44:53+00', '2025-06-03 16:20:12.527+00', false, '2025-06-03 15:44:53.654287+00', '2025-06-03 16:20:12.729419+00'),
	('4bdba1e4-b27a-46e0-b753-08d6184884a8', 'b88b49d1-c394-491e-aaa7-cc196250f0e4', 'week_day', '2025-06-03 15:55:16+00', '2025-06-03 16:20:16.328+00', false, '2025-06-03 15:55:16.361515+00', '2025-06-03 16:20:16.506528+00'),
	('35d36c5b-f091-4fb9-af25-f74a37a6daea', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-06-03 16:20:20+00', NULL, true, '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00');


--
-- Data for Name: shift_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_assignments" ("id", "shift_id", "department_id", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('6be551f6-7325-4ca0-8907-5cbc24e5b794', 'f6e5f57f-23d5-449e-825b-0bad71119102', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('deaded40-ff5e-4677-b8b5-e73d40313e4d', 'f6e5f57f-23d5-449e-825b-0bad71119102', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5ab5397e-11eb-411f-a46a-63772ff7e394', 'f6e5f57f-23d5-449e-825b-0bad71119102', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ed8f16c8-9e6c-4bb3-ac34-31e4bcc50052', 'f6e5f57f-23d5-449e-825b-0bad71119102', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('27d4f726-ac18-48c3-b8c7-08107cc4bbc8', 'f6e5f57f-23d5-449e-825b-0bad71119102', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fa1b7278-7d97-4b38-a9b4-6d12e01ce520', 'f6e5f57f-23d5-449e-825b-0bad71119102', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('07f9762d-89e6-4997-85ed-b07ed6db0e4c', 'be379e15-5712-454f-9c1a-e429358828ec', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('23ed12b5-6d4d-4c47-a1c9-4c02982951b8', 'be379e15-5712-454f-9c1a-e429358828ec', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('21bc535a-a4a0-4f98-a5f7-e4b35a487b48', 'be379e15-5712-454f-9c1a-e429358828ec', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f9b5c175-fd6e-406c-aa77-dbfa30efb294', 'be379e15-5712-454f-9c1a-e429358828ec', 'c06cd3c4-8993-4e7b-b198-a7fda4ede658', '20:00:00', '04:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5c86c555-9138-45a8-89a5-d1aa224ae3a9', '9bc33d1c-2914-454c-bafc-e23374cc170b', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b8a9951b-0ded-4c86-9dfe-c649b693010c', '9bc33d1c-2914-454c-bafc-e23374cc170b', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d4ef7a74-3551-45c6-9e61-db4334d34ba0', '9bc33d1c-2914-454c-bafc-e23374cc170b', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('af848a1a-1862-405c-8a9b-4cdd0026feee', '9bc33d1c-2914-454c-bafc-e23374cc170b', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('096a2332-a54c-4d29-9d5e-f0e446204750', '9bc33d1c-2914-454c-bafc-e23374cc170b', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('59aa5d0c-7227-4c1f-9753-63def99d222b', '9bc33d1c-2914-454c-bafc-e23374cc170b', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c0117771-8eff-4ab3-90a8-8c8ee4d8e0f8', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c7f8f6da-c319-4dc3-a45c-d45d1dafe628', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('88e18046-8649-41a2-9479-450f30477741', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('956f3bff-3b74-4d31-813c-7268b0c7163b', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a6365568-b88b-4cb8-8112-591c7c88c032', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c18f6ed3-8b48-489d-86c9-6c466f51a469', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8a01fd64-0cd2-40fb-a60c-d9d8a3fab1d5', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d3df44b2-2a23-41b1-ab5a-659d2dee78de', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e2e17715-7764-4cf6-b9d9-170271b094ad', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3db65307-2f16-4191-be96-811f9497b00e', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cce4665e-8e83-4435-8190-574f0abbcbba', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3f2ff3a3-cadf-418a-9b02-5a29cafb18be', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('dd29360e-d352-4d15-9a8a-cdddaf820ad1', '73492413-331f-4373-94ec-20735ee40dc9', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '04:00:00', '#4285F4', '2025-05-29 17:35:40.559675+00', '2025-05-29 17:35:40.559675+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('230a86be-da50-4575-bb88-9778b8356c14', '73492413-331f-4373-94ec-20735ee40dc9', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-29 17:35:40.559675+00', '2025-05-29 17:35:40.559675+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f67880f8-5bcb-4d00-8caf-4ad7cf608643', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5af5ac9d-c8a8-48c8-9291-4ec6e2814fa1', '54d0bbe8-6cb1-461e-99bb-2d746affa629', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7fe8ae13-51fb-4960-97af-21d509109fcc', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('38bbe850-6e60-449b-8669-074c1c36b249', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('da82ee9c-020c-494a-a919-091aadb60843', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a3d701d0-3a8d-4c2d-95b4-aef7703704ee', '54d0bbe8-6cb1-461e-99bb-2d746affa629', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('143971c2-e11e-4af6-853c-d31cf6cbe108', '485da1ff-6aba-4442-97c9-de053be8b587', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('44e1d099-c9a4-4d2a-978b-7d3b9b9a1a7b', '485da1ff-6aba-4442-97c9-de053be8b587', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('182147cc-cd57-49ab-924e-e2be33567341', '485da1ff-6aba-4442-97c9-de053be8b587', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('21598afe-5f84-4c4b-892e-44f01137e9f1', '485da1ff-6aba-4442-97c9-de053be8b587', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b5533cc0-0074-4ed4-85d1-97f72cf3953c', '485da1ff-6aba-4442-97c9-de053be8b587', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1a6e6dbb-da84-464d-93c0-75aecea6f0b6', '485da1ff-6aba-4442-97c9-de053be8b587', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('633b8fc3-08e5-4a05-9e38-c7ae5c2913e2', '5980a43c-90e5-4721-92f9-d4f6ee516614', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8d2f167d-108e-447f-9f2f-e368ba42803c', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a37a53d1-bd7e-4b8f-943e-337ab7c748c2', '5980a43c-90e5-4721-92f9-d4f6ee516614', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('33a5a9d6-e40e-4aa6-9dd5-229cd09c1c9d', '5980a43c-90e5-4721-92f9-d4f6ee516614', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9558fff4-06fb-4bb8-914b-6932606d8a66', '5980a43c-90e5-4721-92f9-d4f6ee516614', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('af8eb0c0-3595-4a03-a14d-8df47947f256', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('abf21678-5f89-4712-b8b5-250b812e744b', 'aceab786-878c-4e03-8933-2351d19e6ee6', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '04:00:00', '#4285F4', '2025-05-31 16:54:19.752666+00', '2025-05-31 16:54:19.752666+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('213405e8-6879-4c49-abbb-77c61557969c', 'aceab786-878c-4e03-8933-2351d19e6ee6', '81c30d93-8712-405c-ac5e-509d48fd9af9', '20:00:00', '04:00:00', '#4285F4', '2025-05-31 16:54:19.752666+00', '2025-05-31 16:54:19.752666+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('adbe812f-9f26-44e2-9ee9-8ce76203941f', 'aceab786-878c-4e03-8933-2351d19e6ee6', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-31 16:54:19.752666+00', '2025-05-31 16:54:19.752666+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a9f77612-f83e-44c0-bd53-ffdf1a6a3de1', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6ead2b5a-9f91-4be0-a927-f125b5e393cc', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6bcf6c84-ed4f-4ae1-8830-d0a41596db44', '19ee13f3-d97b-45d6-8716-1243ad8ca120', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a62c9c44-3ea6-49b2-8807-4b4b15036be6', '19ee13f3-d97b-45d6-8716-1243ad8ca120', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0cc3223e-eee1-4b88-add6-12451f3c06fb', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('bd62e104-bae4-4560-af74-6d75492d400b', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a5f14a04-fbc5-4198-8062-2c46c029b9a4', 'cd388712-a45d-4584-a902-c168831a9e34', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '04:00:00', '#4285F4', '2025-05-31 18:29:16.258854+00', '2025-05-31 18:29:16.258854+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('bb23d77a-dfa7-4ee8-a4b6-4dc729d8cbee', 'cd388712-a45d-4584-a902-c168831a9e34', '81c30d93-8712-405c-ac5e-509d48fd9af9', '20:00:00', '04:00:00', '#4285F4', '2025-05-31 18:29:16.258854+00', '2025-05-31 18:29:16.258854+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('769b7e5a-7157-4b6f-9069-ed3267ab61c5', 'cd388712-a45d-4584-a902-c168831a9e34', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-05-31 18:29:16.258854+00', '2025-05-31 18:29:16.258854+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c91f0ebe-a97a-4f6a-a33c-9d7187dbaf39', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4ceb0d76-da1e-4a10-822e-2eae1193f552', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b800d194-efaa-44f7-b20e-b15665c4aaca', 'cd7a5899-34e6-4616-8450-0ed8082a236e', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e24961e2-e6bf-47a5-8cce-e821b43adcf8', 'cd7a5899-34e6-4616-8450-0ed8082a236e', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1d0dc262-a009-4269-a63a-26e76e56ab4d', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('861f3566-0c3c-4918-93fa-646902283c8b', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('44c6f487-1c08-4f71-bf49-bc0511949d40', '1d0d0a5a-fbee-4c8e-a3cf-78c4eb1a003c', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '04:00:00', '#4285F4', '2025-06-01 14:51:20.424382+00', '2025-06-01 14:51:20.424382+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e003ff64-6cdc-44a7-9d38-96e136cf56f6', '1d0d0a5a-fbee-4c8e-a3cf-78c4eb1a003c', '81c30d93-8712-405c-ac5e-509d48fd9af9', '20:00:00', '04:00:00', '#4285F4', '2025-06-01 14:51:20.424382+00', '2025-06-01 14:51:20.424382+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('dbe824ed-6b2b-49b4-85ed-48dc1e531510', '1d0d0a5a-fbee-4c8e-a3cf-78c4eb1a003c', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '04:00:00', '#4285F4', '2025-06-01 14:51:20.424382+00', '2025-06-01 14:51:20.424382+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6758ba99-7e0a-4cab-9713-d86559a75c17', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a030f4a2-01a9-4a74-a79c-3868ef8c8958', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d7512fb8-8c75-474a-820f-fc83496d89b9', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('111d6640-aaa9-4d69-ba4a-fd8827a85a87', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3b3d07ad-6bb0-43a6-9d69-7fd1db36275d', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('10f9af10-d503-4c42-99c3-b552a94aa83e', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c59399d5-4194-478e-b42f-f4b5459e549c', '781a97d0-29bd-4e8b-8494-dca63156c45c', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('df80dde9-b0fd-4c18-922d-3294ee623412', '781a97d0-29bd-4e8b-8494-dca63156c45c', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#f443b3', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('71084014-3725-4181-822e-7eb027c3212f', '781a97d0-29bd-4e8b-8494-dca63156c45c', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9b4d44d9-e6cb-45c1-9743-feaf56625e4a', '781a97d0-29bd-4e8b-8494-dca63156c45c', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fa9eed4d-83a8-4c8c-a5e5-3235ffc9ffbb', '781a97d0-29bd-4e8b-8494-dca63156c45c', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('41cccb7a-e53b-4d06-a20a-d8d8e6b92366', '781a97d0-29bd-4e8b-8494-dca63156c45c', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5e455c04-29f9-49a2-84c6-d918b8cfb116', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('489f6db1-d1fe-446c-b61c-aa8842f6c64c', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e0a79e1d-c63f-4aad-ba21-1a631f7c045b', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fee2f234-ecef-49c0-a9a8-f1aba2054de1', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e86ace6d-6d14-4b94-a745-8eb827e3f4fa', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7beda791-2469-4b28-9fa3-0e82a7298bc4', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0fe87492-422f-4216-9edb-8d70e9c166a2', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('20cd9a0a-39f1-4757-af21-85957e504ba4', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('79792e6f-fa48-4072-9310-008e60ddedd9', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e45f1a05-295d-4552-b25c-f6033a68cbff', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('46b4ee96-359c-4765-8a9b-f6c87c6624df', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1e958bb7-f6ab-469c-8a1b-34764baa40b5', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7f2f0c66-a5f7-42e5-ab78-057ae79353e6', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('517ffb70-41d9-4f73-b114-ba023f453b17', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('303305b8-7257-4500-80b4-fe7f76cb2eef', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('01731df7-add4-4b37-a4c9-5e4576487bfb', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1407d29a-f017-4e86-9cbd-7a3e7091e636', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e9c3647a-4262-4477-9e9f-e0497889f5b2', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 3, 3, 3, 3, 3, 3, 3, 3),
	('1e0be880-5d6a-4a64-ad66-f71e65e34c84', 'd357c573-8c18-42d0-a8cf-27f326454959', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0ec77e11-b1ce-42c0-bd56-d347d60a1528', 'd357c573-8c18-42d0-a8cf-27f326454959', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('63f5a5f3-7396-4c24-b525-03ca5e4bdd39', 'd357c573-8c18-42d0-a8cf-27f326454959', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e1cc9dda-eb09-4daa-a12a-04b7a11161ce', 'd357c573-8c18-42d0-a8cf-27f326454959', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1a4f1c42-6444-4370-95d2-069f8119ce66', 'd357c573-8c18-42d0-a8cf-27f326454959', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a9574682-43b3-4ae4-8bc1-577486394cd9', 'd357c573-8c18-42d0-a8cf-27f326454959', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('32f1e518-b020-4a7d-a6df-19a9008141e1', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('938e0b4d-d3e4-49d1-bd2c-44154df9a258', '43f0073b-ab8d-4ed6-af91-4cc58492637d', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('91723270-5ef2-4415-b6d6-48a09317e86d', '43f0073b-ab8d-4ed6-af91-4cc58492637d', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0f01fd30-244f-443e-a3a0-f1e2d2f4eb38', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('996e3c3a-8c51-4958-9ca0-aad6d9fb35a9', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('39d39d82-d402-4450-af3d-94206f1ea68c', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('45e8ecf8-9860-413c-b712-3c083d750bf1', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2ebaf678-c58d-4b18-86c6-74b73c873996', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3dbba6a9-08b4-4a47-b955-eb907fcbdd56', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('61da27c7-f19d-421c-b7c4-7a90b5019f02', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('95cad7de-89e8-44fb-84cf-1d14d380734b', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('2b448236-e114-4685-8cea-b5ff9e89dd8a', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7b384b04-9b09-4190-bd4f-6efe9af5075c', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9e93ff91-e441-4735-b9b0-714c8ce13461', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4cfe4f86-9751-45b2-b816-4779477e42e9', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4b97cbc2-2a87-4aef-a118-0f6da06e783a', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9d46cd1a-e854-4c3e-9185-04b90ddd2fec', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('084e7167-b21b-4982-b50e-c03e7789a214', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('436a4fbd-5824-4c8b-bce7-dc7b249312d7', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('474ee012-82f1-4fd7-816d-26ca32cfe7ea', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3b74dda7-df92-4629-a930-acd1e19bba23', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('63d1feba-3118-4ab7-9311-92df474d05d6', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('80477a09-9ab3-4fb6-a7fb-4c30202fe224', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('3bccfb10-85e9-43aa-84ef-032d481099f4', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d2cdced4-f149-4c9a-8e93-bd737b00954c', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3e729c64-69ef-48df-8eda-7a6f1439dd8d', '4bdba1e4-b27a-46e0-b753-08d6184884a8', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0c897272-0960-43d8-8c41-6ba55fe1b686', '4bdba1e4-b27a-46e0-b753-08d6184884a8', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('17653260-53c8-4a59-88df-516a233070a6', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('98ee2aed-ea64-416a-b51b-c0183011ace3', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('e54e48ea-adfb-40bc-b183-36fb0ac1bfd8', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8210c90d-dacb-4d9b-b21e-6a21c8c753da', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '81c30d93-8712-405c-ac5e-509d48fd9af9', '11:00:00', '18:00:00', '#e22400', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4368fffe-4d10-4306-b3ae-c7d81b4447e5', '35d36c5b-f091-4fb9-af25-f74a37a6daea', 'd82e747e-5e94-44cb-9fd6-2ab98f4c3f53', '08:00:00', '20:00:00', '#d357fe', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d67b3069-a8bf-4006-bcc9-f03a80020430', '35d36c5b-f091-4fb9-af25-f74a37a6daea', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '17:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6f38f657-3d54-499d-be42-c06db593f58f', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4515be68-a0b5-4aee-b79c-8c007567916c', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4e7a27', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 5, 5, 5, 5, 5, 5, 5, 5),
	('56bb2a01-4898-4a52-b2c0-8ff5c2034e27', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '22:00:00', '#f443b3', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: shift_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_porter_assignments" ("id", "shift_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('65cf4a66-c3fa-4c2b-9225-d734197e8763', '27d4f726-ac18-48c3-b8c7-08107cc4bbc8', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('a336fe4b-ba26-45d2-9da3-1f3221b92bea', 'fa1b7278-7d97-4b38-a9b4-6d12e01ce520', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('5f1a167a-e202-4a40-925d-22bae6ba32ed', 'fa1b7278-7d97-4b38-a9b4-6d12e01ce520', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('9e68f528-f083-487a-9d61-cdf3731f3176', 'fa1b7278-7d97-4b38-a9b4-6d12e01ce520', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('74d5713f-5bad-428f-9a8a-eb41abc87590', '6be551f6-7325-4ca0-8907-5cbc24e5b794', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '11:00:00', '18:00:00', '2025-05-29 14:39:23.639682+00', '2025-05-29 14:39:23.639682+00'),
	('cb47b0a8-180a-4fdb-a673-87e0c0e8639c', '096a2332-a54c-4d29-9d5e-f0e446204750', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('666b747c-f066-4b50-a8ff-884f42ac9869', '59aa5d0c-7227-4c1f-9753-63def99d222b', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('9a600a6b-c931-4cbb-9630-7ebb90d62465', '59aa5d0c-7227-4c1f-9753-63def99d222b', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('a879c04e-e2c3-4042-982a-ff995b3ec572', '59aa5d0c-7227-4c1f-9753-63def99d222b', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('798453ed-3ae0-49f4-99a1-839404567d1e', 'a6365568-b88b-4cb8-8112-591c7c88c032', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('8707537d-aadf-4460-a5f7-b8bde7d6c5bf', 'c18f6ed3-8b48-489d-86c9-6c466f51a469', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('62978a6c-0931-4e2b-b465-1f400dade91e', '23ed12b5-6d4d-4c47-a1c9-4c02982951b8', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:32:00', '17:32:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('ac3fce54-13a9-42f5-b1e8-1aaa41d6d6e0', '23ed12b5-6d4d-4c47-a1c9-4c02982951b8', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:49:00', '20:49:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('81f0cf50-5ceb-44c6-999c-9e0b3cdb2ad9', 'f9b5c175-fd6e-406c-aa77-dbfa30efb294', '394d8660-7946-4b31-87c9-b60f7e1bc294', '19:12:00', '21:12:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('c76bb843-6d13-4295-88be-57913a8d81be', 'c18f6ed3-8b48-489d-86c9-6c466f51a469', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('bd0caa9d-a34f-4cd3-812e-63ca04f9c52e', 'c18f6ed3-8b48-489d-86c9-6c466f51a469', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('6da82026-dc1e-4f71-b04d-dd19665abc7e', '3db65307-2f16-4191-be96-811f9497b00e', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('1ee86bb3-6ffa-4911-88e3-11c37fad159c', 'cce4665e-8e83-4435-8190-574f0abbcbba', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('d23f03d6-f700-40bd-84e8-96ea9f518d37', 'cce4665e-8e83-4435-8190-574f0abbcbba', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('1991f130-1cae-4e5f-b319-6a9b4d0325a3', 'cce4665e-8e83-4435-8190-574f0abbcbba', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('5cc2cbcf-9073-4e7c-81ff-0b5ebc3da698', '3f2ff3a3-cadf-418a-9b02-5a29cafb18be', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '19:31:00', '20:31:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('c23c0489-8a66-47dd-ac43-8d4b05fee638', 'd3df44b2-2a23-41b1-ab5a-659d2dee78de', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '08:00:00', '20:00:00', '2025-05-29 17:34:28.636038+00', '2025-05-29 17:34:28.636038+00'),
	('ec8f28de-33b8-44e1-b91d-4c659d5ecd65', '5af5ac9d-c8a8-48c8-9291-4ec6e2814fa1', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('ea532623-ab0e-4ca7-b910-5a55b61c6161', '7fe8ae13-51fb-4960-97af-21d509109fcc', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('c9cc876e-67c8-463e-a8e5-dd1a6b6b4857', '7fe8ae13-51fb-4960-97af-21d509109fcc', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('674e9cef-f109-4e37-97af-3020b17ace72', '7fe8ae13-51fb-4960-97af-21d509109fcc', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('ed574acd-e545-4924-bb42-8dbe24913ba8', '38bbe850-6e60-449b-8669-074c1c36b249', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:00:00', '15:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('dfc5ae9a-32e2-4cbe-b1da-aae01a1ae7e1', '38bbe850-6e60-449b-8669-074c1c36b249', '2e74429e-2aab-4bed-a979-6ccbdef74596', '15:00:00', '18:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('fa4f0925-8c06-453d-bec9-f4dbde965635', '44e1d099-c9a4-4d2a-978b-7d3b9b9a1a7b', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('0d6de8e1-b0b0-48fb-bd91-0c0a22716f8c', '182147cc-cd57-49ab-924e-e2be33567341', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('f89f66f6-e365-40e1-9fbd-aed7ec650ad1', '182147cc-cd57-49ab-924e-e2be33567341', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('0b17ec26-4ae3-4514-ac8e-1ea18c3c9150', '182147cc-cd57-49ab-924e-e2be33567341', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('2009dce5-7ebf-4ccf-99db-72a4ddc0b5ce', '21598afe-5f84-4c4b-892e-44f01137e9f1', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:00:00', '15:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('54f18c21-d297-420a-ac71-31798a85d952', '21598afe-5f84-4c4b-892e-44f01137e9f1', '2e74429e-2aab-4bed-a979-6ccbdef74596', '15:00:00', '18:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('e097233f-bd23-428b-81ac-e8ddac4d44b1', '8d2f167d-108e-447f-9f2f-e368ba42803c', '050fa6e6-477b-4f83-aae4-3e13c954ca6a', '09:00:00', '17:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('2ff87882-7afb-4931-8dfe-c9f790879dc3', 'a37a53d1-bd7e-4b8f-943e-337ab7c748c2', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '06:00:00', '14:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('26e516af-1a33-43eb-9303-e524fd07116e', 'a37a53d1-bd7e-4b8f-943e-337ab7c748c2', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '09:00:00', '17:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('058062f1-24ee-483a-b2b8-87a81149291b', 'a37a53d1-bd7e-4b8f-943e-337ab7c748c2', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '13:00:00', '21:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('27e23d4e-4ca9-43c3-bb25-a56a1ad697a3', '33a5a9d6-e40e-4aa6-9dd5-229cd09c1c9d', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:00:00', '15:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('44a2f9e9-8177-4d93-9752-967c96f2b19e', '33a5a9d6-e40e-4aa6-9dd5-229cd09c1c9d', '2e74429e-2aab-4bed-a979-6ccbdef74596', '15:00:00', '18:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('927bfb70-0848-44e7-a75d-e207756b65e3', '8d2f167d-108e-447f-9f2f-e368ba42803c', '786d6d23-69b9-433e-92ed-938806cb10a8', '08:00:00', '14:00:00', '2025-05-30 11:13:59.60038+00', '2025-05-30 11:13:59.60038+00'),
	('e0b81f75-1e65-41ec-8ca3-2c5b7a7e9a37', '6ead2b5a-9f91-4be0-a927-f125b5e393cc', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('775712ac-78fa-4ce9-9b69-941454dcd3ab', '6ead2b5a-9f91-4be0-a927-f125b5e393cc', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '09:00:00', '17:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('b04b879e-db3a-4646-8d28-c205b0b7babf', '6ead2b5a-9f91-4be0-a927-f125b5e393cc', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '13:00:00', '23:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('6116ef93-2051-4d76-825c-978c4f54aecc', 'a62c9c44-3ea6-49b2-8807-4b4b15036be6', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('bcd64e5e-6bee-45aa-8549-90f9488bd463', 'a62c9c44-3ea6-49b2-8807-4b4b15036be6', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('b25d98d9-0272-422e-b5f6-25a6b34a54a2', '0cc3223e-eee1-4b88-add6-12451f3c06fb', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('630675e6-f896-4339-bc79-7fa68a25c1ce', '0cc3223e-eee1-4b88-add6-12451f3c06fb', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('0f6cf851-5ec5-4695-aa0b-8eb2cb1447fb', 'bd62e104-bae4-4560-af74-6d75492d400b', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('fe70ace3-5f3b-4f26-bcc1-c11e60d5cc7f', 'bd62e104-bae4-4560-af74-6d75492d400b', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('774b2c4c-480d-4395-af16-c9336326f7b0', '6ead2b5a-9f91-4be0-a927-f125b5e393cc', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('ce2b7eae-1f37-4654-8fd4-820e8a259142', '4ceb0d76-da1e-4a10-822e-2eae1193f552', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('4dcb46aa-2a2f-4bc8-98d4-11fed4d38439', 'e24961e2-e6bf-47a5-8cce-e821b43adcf8', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('702de30a-353d-4062-af3a-3e5dc126dc78', 'e24961e2-e6bf-47a5-8cce-e821b43adcf8', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('20033ff2-c3e5-426e-bfe7-a6d4e12702fa', '1d0dc262-a009-4269-a63a-26e76e56ab4d', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('4a7995e6-8db6-4da2-8aa2-f6920db2b0fc', '1d0dc262-a009-4269-a63a-26e76e56ab4d', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('00fe0db7-deca-4f9b-a416-0ab3d8bef9f9', '861f3566-0c3c-4918-93fa-646902283c8b', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('77bc4ada-c4fb-425c-b3fd-e19f52515709', '4ceb0d76-da1e-4a10-822e-2eae1193f552', '2e74429e-2aab-4bed-a979-6ccbdef74596', '13:00:00', '22:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('70500335-a142-428a-b27c-311bf017f75f', '861f3566-0c3c-4918-93fa-646902283c8b', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('ef68669f-4292-4f64-9d98-2cf187edb523', '111d6640-aaa9-4d69-ba4a-fd8827a85a87', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('e6976075-c68a-460f-b8f3-2f8b7ac9b70b', '111d6640-aaa9-4d69-ba4a-fd8827a85a87', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('e2a65773-090f-4ced-af39-2e388b345c4a', '3b3d07ad-6bb0-43a6-9d69-7fd1db36275d', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('7ca40843-3535-44d5-887d-40031f36367e', '3b3d07ad-6bb0-43a6-9d69-7fd1db36275d', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('eb3130e1-14dd-4838-8242-226b6737e7a5', '10f9af10-d503-4c42-99c3-b552a94aa83e', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('186f0c79-3ab3-4e0e-95dc-3b1be92f08a3', '10f9af10-d503-4c42-99c3-b552a94aa83e', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('2b8ebef4-3bbd-4ba4-9b3c-b8544e3dabc3', 'a030f4a2-01a9-4a74-a79c-3868ef8c8958', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '17:00:00', '20:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('be967639-fd1c-4cbf-ac72-82661f24966a', 'a030f4a2-01a9-4a74-a79c-3868ef8c8958', 'ccac560c-a3ad-4517-895d-86870e9ad00a', '14:00:00', '17:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('4d6e9314-c1ec-4588-b97a-ce5adc65eea1', 'a030f4a2-01a9-4a74-a79c-3868ef8c8958', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '06:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('88ce4434-cf69-40c8-83e2-671a23df902d', 'a030f4a2-01a9-4a74-a79c-3868ef8c8958', 'af42f57f-1437-4320-b1a2-2b0051948de3', '08:00:00', '20:00:00', '2025-06-01 15:06:24.357052+00', '2025-06-01 15:06:24.357052+00'),
	('0b345eba-2c98-458c-857e-c0632d495c5c', 'df80dde9-b0fd-4c18-922d-3294ee623412', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '15:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('7fb21ed7-d690-4e7c-810e-50f29f3f311f', 'df80dde9-b0fd-4c18-922d-3294ee623412', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '17:00:00', '19:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('92ef64cf-6b21-48be-9634-4a7f506bf073', 'df80dde9-b0fd-4c18-922d-3294ee623412', 'ccac560c-a3ad-4517-895d-86870e9ad00a', '15:00:00', '16:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('2fd33dbf-76d3-4ecc-bd1a-6922f05d7d61', '9b4d44d9-e6cb-45c1-9743-feaf56625e4a', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('3d84fb2f-0805-43c9-94a1-09ea2f017852', '9b4d44d9-e6cb-45c1-9743-feaf56625e4a', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('afd1478e-8892-4d37-aec9-3a0dc63803c6', 'fa9eed4d-83a8-4c8c-a5e5-3235ffc9ffbb', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('ff66895f-0a5b-4225-8e6a-66a507e63b2c', 'fa9eed4d-83a8-4c8c-a5e5-3235ffc9ffbb', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('05fa55da-9ca2-427f-b1eb-63b9e82233ac', '41cccb7a-e53b-4d06-a20a-d8d8e6b92366', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('894d5328-12ca-4681-8c5e-29ee131cf2b9', '41cccb7a-e53b-4d06-a20a-d8d8e6b92366', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('4b8778d2-a2c5-4f88-aa90-755de2844105', 'e0a79e1d-c63f-4aad-ba21-1a631f7c045b', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('09bd0398-e071-492d-9dda-69247e34cebd', 'e0a79e1d-c63f-4aad-ba21-1a631f7c045b', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('86f53c9c-d612-430e-98a7-d30430d5fe6d', 'fee2f234-ecef-49c0-a9a8-f1aba2054de1', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('125a13d5-c717-462a-a113-88ee105668e5', 'fee2f234-ecef-49c0-a9a8-f1aba2054de1', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('df2ba2c6-54af-4810-85e0-d325236b8d86', 'e86ace6d-6d14-4b94-a745-8eb827e3f4fa', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('a5175c92-ff5f-4219-ae45-4c86e5f75e22', 'e86ace6d-6d14-4b94-a745-8eb827e3f4fa', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('f6d2a003-a8d5-43cb-8597-9296d66f13e8', '7beda791-2469-4b28-9fa3-0e82a7298bc4', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('2515e248-eb5e-49d0-ba40-41d226ee076c', '7beda791-2469-4b28-9fa3-0e82a7298bc4', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('8390fd1a-9ece-45f0-8470-39c44395e685', '79792e6f-fa48-4072-9310-008e60ddedd9', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('8ff1cb2f-ba1c-4f15-a9bf-1e0e086e8738', '79792e6f-fa48-4072-9310-008e60ddedd9', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('7bbd0260-3ab9-452c-84c6-3ed74f4e4741', 'e45f1a05-295d-4552-b25c-f6033a68cbff', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('7f217343-0bb7-4c21-8f5e-08d9ada13832', 'e45f1a05-295d-4552-b25c-f6033a68cbff', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('89a82294-f296-4b82-ad82-b5bd37e8ffb9', '46b4ee96-359c-4765-8a9b-f6c87c6624df', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('fbf54034-a345-4f56-9eaf-38fc44e30e23', '46b4ee96-359c-4765-8a9b-f6c87c6624df', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('fbaea37b-0b70-4da9-9c66-848fb588b79d', '1e958bb7-f6ab-469c-8a1b-34764baa40b5', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('0447bba5-8886-4060-862f-74296d797e1b', '1e958bb7-f6ab-469c-8a1b-34764baa40b5', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('a984948b-fc67-4faf-94f9-9c50e8d4b786', '303305b8-7257-4500-80b4-fe7f76cb2eef', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('9f6f011e-335b-4c1d-b006-2fbdff4dca2a', '303305b8-7257-4500-80b4-fe7f76cb2eef', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('d5272899-2414-498a-9f99-6cd21865280f', '01731df7-add4-4b37-a4c9-5e4576487bfb', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('2d69991a-bd19-45e8-9c7c-a118038ad00f', '01731df7-add4-4b37-a4c9-5e4576487bfb', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('32fc5905-ab2d-4d97-b3f4-81110446deb6', '1407d29a-f017-4e86-9cbd-7a3e7091e636', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('2fe782b5-a86f-4b6a-a2ce-e904a39c535a', '1407d29a-f017-4e86-9cbd-7a3e7091e636', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('bea3bb2b-4bd5-477f-b360-08029e115f48', 'e9c3647a-4262-4477-9e9f-e0497889f5b2', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('98215a86-075c-47a9-b2db-e5aac41c104a', 'e9c3647a-4262-4477-9e9f-e0497889f5b2', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('1eefa53b-e990-4260-a231-bea99b85ff23', '63f5a5f3-7396-4c24-b525-03ca5e4bdd39', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('b1a4f11a-b149-4479-8695-ccc8105ff09c', '63f5a5f3-7396-4c24-b525-03ca5e4bdd39', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('f603cd85-5d3c-445d-b80d-88ac27cbaffa', 'e1cc9dda-eb09-4daa-a12a-04b7a11161ce', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('58eea4a7-0fb9-418a-90f7-334f9a25854c', 'e1cc9dda-eb09-4daa-a12a-04b7a11161ce', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('b6503c8b-c087-45c5-954f-dea262649918', '1a4f1c42-6444-4370-95d2-069f8119ce66', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('10e81e26-ba8d-45d7-9146-9253362fe3e0', '1a4f1c42-6444-4370-95d2-069f8119ce66', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('22070f05-de67-4a36-a638-61c926231f6d', 'a9574682-43b3-4ae4-8bc1-577486394cd9', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('72e41281-9663-4de8-b29d-cc2065879cf2', 'a9574682-43b3-4ae4-8bc1-577486394cd9', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('acf8d740-7dac-4df9-a0de-42d631e4b11f', '91723270-5ef2-4415-b6d6-48a09317e86d', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('cdf1878a-031e-414c-acb9-1e57a7fb0a7c', '91723270-5ef2-4415-b6d6-48a09317e86d', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('fb722196-a26e-49bf-bff1-6a9924d2f90b', '0f01fd30-244f-443e-a3a0-f1e2d2f4eb38', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('04014040-4e2e-4961-99e6-8632ee508bf6', '0f01fd30-244f-443e-a3a0-f1e2d2f4eb38', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('fa590d5d-5b4e-493f-bc39-2ec5acb48ae3', '996e3c3a-8c51-4958-9ca0-aad6d9fb35a9', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('18636202-66f1-4369-b643-668dba164180', '996e3c3a-8c51-4958-9ca0-aad6d9fb35a9', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('7e00241f-4e37-4366-9c5b-3fd640a70869', '39d39d82-d402-4450-af3d-94206f1ea68c', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('ef20640c-c02a-451a-87ac-d208e214e87c', '39d39d82-d402-4450-af3d-94206f1ea68c', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('8af60987-e35b-47a7-9fb6-97cee016b190', '3dbba6a9-08b4-4a47-b955-eb907fcbdd56', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('383897cf-39a6-4bf2-96bc-18168db3983f', '3dbba6a9-08b4-4a47-b955-eb907fcbdd56', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('8be70ab3-27b7-4b5a-b2d7-cf8f235b5e88', '61da27c7-f19d-421c-b7c4-7a90b5019f02', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('206fd273-52d1-4c79-901a-398c69572146', '61da27c7-f19d-421c-b7c4-7a90b5019f02', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('20a099d4-21dd-4ff0-be04-ca231ccd5fea', '95cad7de-89e8-44fb-84cf-1d14d380734b', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('9a648fe5-debd-4587-9a00-8ae3901130f0', '95cad7de-89e8-44fb-84cf-1d14d380734b', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('985777c3-a7cc-42ef-9421-a71ffba815e3', '2b448236-e114-4685-8cea-b5ff9e89dd8a', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('06ece6aa-daa5-440c-8636-f24727a8da64', '2b448236-e114-4685-8cea-b5ff9e89dd8a', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('47ba508c-d9e5-41cd-bcef-eef8097d5e05', '4cfe4f86-9751-45b2-b816-4779477e42e9', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('c902e490-752e-4722-bb27-cf1b11e36929', '4cfe4f86-9751-45b2-b816-4779477e42e9', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('b74ef263-a84b-4480-a940-9079d4ade386', '4b97cbc2-2a87-4aef-a118-0f6da06e783a', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('0cabb209-1931-406b-b440-4914844b18b3', '4b97cbc2-2a87-4aef-a118-0f6da06e783a', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('c4c08364-aa21-40a5-a3e2-41c0239fe262', '9d46cd1a-e854-4c3e-9185-04b90ddd2fec', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('06a2f0bd-c1ed-4912-827e-7247944a3380', '9d46cd1a-e854-4c3e-9185-04b90ddd2fec', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('97bc5261-06d5-49ee-bfa3-9dea735bdbc5', '084e7167-b21b-4982-b50e-c03e7789a214', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '06:00:00', '14:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('4d4fd8bb-3e46-429c-b757-6b7ba83dbeaa', '084e7167-b21b-4982-b50e-c03e7789a214', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('0e0068fd-9704-4452-bd9d-28f56675999a', '3b74dda7-df92-4629-a930-acd1e19bba23', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('d8b8429b-e78e-46fc-89b3-1f09dc780681', '3b74dda7-df92-4629-a930-acd1e19bba23', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('bd4bc05c-1ebc-4d99-983f-488cfa361a9b', '63d1feba-3118-4ab7-9311-92df474d05d6', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('4d5afd63-9988-484e-9cf1-5240eebab598', '63d1feba-3118-4ab7-9311-92df474d05d6', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('fe5d9fc3-6a45-45f8-9652-609b959b0299', '80477a09-9ab3-4fb6-a7fb-4c30202fe224', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('b5bd4354-ea4e-42e2-8bb3-bf282c3286f9', '80477a09-9ab3-4fb6-a7fb-4c30202fe224', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('497bd847-e768-4a42-87a7-912cce021ad9', '3bccfb10-85e9-43aa-84ef-032d481099f4', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('8ab0915c-ab76-49cb-a60f-221f13b7aca5', '3bccfb10-85e9-43aa-84ef-032d481099f4', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('bcf5a0ca-01fb-402f-8e5f-6785b6f07adb', '0c897272-0960-43d8-8c41-6ba55fe1b686', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('c925be07-01bb-497b-aa4b-195989fcd89f', '0c897272-0960-43d8-8c41-6ba55fe1b686', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('c418dd37-00b7-482a-b671-f392750e44ad', '17653260-53c8-4a59-88df-516a233070a6', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('7a1249aa-a12c-4a78-9a78-3d42d85b54b8', '17653260-53c8-4a59-88df-516a233070a6', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('5a07a922-0060-49ea-a775-5ac2a5443168', '98ee2aed-ea64-416a-b51b-c0183011ace3', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('c7e4cb08-41c4-45ed-a5e0-ee1b9d051934', '98ee2aed-ea64-416a-b51b-c0183011ace3', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('2baf24b6-ff30-47ce-a076-9335856941d3', 'e54e48ea-adfb-40bc-b183-36fb0ac1bfd8', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('48e747a9-ab7d-4835-8c31-6163c5659272', 'e54e48ea-adfb-40bc-b183-36fb0ac1bfd8', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('351be29b-90f1-4726-831c-186a4932cc43', 'd67b3069-a8bf-4006-bcc9-f03a80020430', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('580a9112-ff49-4a6a-bcff-f29bd3acc562', 'd67b3069-a8bf-4006-bcc9-f03a80020430', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('75812b95-d80f-4d18-934f-9cca0b560bd9', '6f38f657-3d54-499d-be42-c06db593f58f', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('93086fe3-4643-4e8d-b58d-aa3b48e83f79', '6f38f657-3d54-499d-be42-c06db593f58f', '534e6bda-2978-47cd-aacc-f1bd3f94e981', '10:00:00', '18:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('f09389e4-fd25-4c98-b410-903adfc513b7', '4515be68-a0b5-4aee-b79c-8c007567916c', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('5f69fda9-3dcd-466f-84c2-9a657a6f362a', '4515be68-a0b5-4aee-b79c-8c007567916c', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('ea4af8b9-db78-47f2-a90e-c48c721dec96', '56bb2a01-4898-4a52-b2c0-8ff5c2034e27', '7884c45a-823f-48c9-a4d4-fd2ad426f144', '08:00:00', '14:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('a7674524-d12d-4dbd-a70c-8b00aab581d4', '56bb2a01-4898-4a52-b2c0-8ff5c2034e27', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00');


--
-- Data for Name: shift_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_defaults" ("id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('01373b67-60e9-4422-a1ae-a8e72d119014', 'week_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00'),
	('524485d0-141a-4574-808b-93410f62ca94', 'weekend_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00'),
	('85cc4d8d-f0fc-477a-b138-56efdcbfcdf1', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00'),
	('2b13f0ba-98fc-4013-9953-0da1418e8ea0', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-05-29 14:01:17.665+00');


--
-- Data for Name: shift_porter_pool; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_porter_pool" ("id", "shift_id", "porter_id", "created_at", "updated_at") VALUES
	('43fbe8c5-49bd-461b-abe4-fc763f7dda96', 'be379e15-5712-454f-9c1a-e429358828ec', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-28 13:48:11.001438+00', '2025-05-28 13:48:11.001438+00'),
	('d2fee56f-66eb-4e4f-b568-6722fa91dadf', 'be379e15-5712-454f-9c1a-e429358828ec', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '2025-05-28 13:48:11.079273+00', '2025-05-28 13:48:11.079273+00'),
	('969b1aa6-05d2-40cd-93bd-d9020d03c26c', 'be379e15-5712-454f-9c1a-e429358828ec', 'e55b1013-7e79-4e38-913e-c53de591f85c', '2025-05-28 13:48:11.146077+00', '2025-05-28 13:48:11.146077+00'),
	('7545fa7c-5b68-4457-9e26-f4223aab0bb9', 'be379e15-5712-454f-9c1a-e429358828ec', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-28 13:48:11.213451+00', '2025-05-28 13:48:11.213451+00'),
	('03ca1821-6685-4709-bfef-f8dab72409cb', 'f6e5f57f-23d5-449e-825b-0bad71119102', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-29 14:22:25.71052+00', '2025-05-29 14:22:25.71052+00'),
	('fdbe0ca5-4c95-4182-85d2-9e8bbb11c8f9', 'f6e5f57f-23d5-449e-825b-0bad71119102', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', '2025-05-29 14:22:25.779041+00', '2025-05-29 14:22:25.779041+00'),
	('5d92efff-b375-4a49-9cc7-36c4ccfde432', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-29 17:25:24.912844+00', '2025-05-29 17:25:24.912844+00'),
	('260857eb-ad4e-431d-a70e-c943a1a93420', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-29 17:25:25.002727+00', '2025-05-29 17:25:25.002727+00'),
	('158a5f14-4b3a-4ab6-9880-80f7c3490e5c', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-29 17:25:25.077915+00', '2025-05-29 17:25:25.077915+00'),
	('ac4ebb94-6eb7-446e-b530-28bb1d634082', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '2e74429e-2aab-4bed-a979-6ccbdef74596', '2025-05-29 17:25:25.157091+00', '2025-05-29 17:25:25.157091+00'),
	('696e9e40-904c-4236-949c-3be20197c5e3', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-05-29 17:33:52.836762+00', '2025-05-29 17:33:52.836762+00'),
	('bdc2837a-7bab-43f4-b14c-3df04b617e56', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '2025-05-29 17:33:52.92781+00', '2025-05-29 17:33:52.92781+00'),
	('48f6db00-f13c-4aef-bb64-b87d1a422157', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '2025-05-29 17:33:52.994231+00', '2025-05-29 17:33:52.994231+00'),
	('9998dce5-7db6-423b-8900-802dad66104b', '485da1ff-6aba-4442-97c9-de053be8b587', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', '2025-05-30 09:01:50.65566+00', '2025-05-30 09:01:50.65566+00'),
	('be262a3a-2802-4018-9275-b191923a4e03', '485da1ff-6aba-4442-97c9-de053be8b587', '78bf0e75-7640-49fb-9d4e-b59e0b3ecf43', '2025-05-30 09:01:50.761261+00', '2025-05-30 09:01:50.761261+00'),
	('b50f31a6-309c-43fc-8adf-2de5b54b60bb', '485da1ff-6aba-4442-97c9-de053be8b587', '4e87f01b-5196-47c4-b424-4cfdbe7fb385', '2025-05-30 09:01:50.841757+00', '2025-05-30 09:01:50.841757+00'),
	('18cb17e9-d6a0-41ae-9681-5aa5a9fefeb1', '485da1ff-6aba-4442-97c9-de053be8b587', '8eaa9194-b164-4cb4-a15c-956299ff28c5', '2025-05-30 09:01:50.936901+00', '2025-05-30 09:01:50.936901+00'),
	('a3325f2e-96e1-4736-8181-50f982cd06f8', '485da1ff-6aba-4442-97c9-de053be8b587', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '2025-05-30 09:01:51.127146+00', '2025-05-30 09:01:51.127146+00'),
	('9a58f7a4-e7d7-4671-88e4-0113b3548ccb', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', '2025-05-30 11:13:44.950885+00', '2025-05-30 11:13:44.950885+00'),
	('49e91cf0-5e28-4e14-958f-4dd6d80d2699', '5980a43c-90e5-4721-92f9-d4f6ee516614', '786d6d23-69b9-433e-92ed-938806cb10a8', '2025-05-30 11:13:44.996875+00', '2025-05-30 11:13:44.996875+00'),
	('c62954e6-2b56-46be-9367-5496afb8fce9', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '2025-05-30 11:13:45.039293+00', '2025-05-30 11:13:45.039293+00'),
	('d9132e06-40b0-4991-a002-76ee3789bb33', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '2025-05-30 11:13:45.077531+00', '2025-05-30 11:13:45.077531+00'),
	('7454c1ec-c343-47ef-9420-8b52096b5b60', '5980a43c-90e5-4721-92f9-d4f6ee516614', '8eaa9194-b164-4cb4-a15c-956299ff28c5', '2025-05-30 11:13:45.118243+00', '2025-05-30 11:13:45.118243+00'),
	('d26d7e8e-ff2b-4d29-8412-d48fe768037a', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-01 15:05:49.865192+00', '2025-06-01 15:05:49.865192+00'),
	('aeadac75-a850-4d3a-a101-a97d761d46eb', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '2025-06-01 15:05:49.929084+00', '2025-06-01 15:05:49.929084+00'),
	('d228a953-0aee-41df-b45b-2126f929593e', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '296edb55-91eb-4d73-aa43-54840cbbf20c', '2025-06-01 15:05:49.991599+00', '2025-06-01 15:05:49.991599+00'),
	('2219cab6-434d-4192-86b9-7de630d4d128', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-01 15:05:50.030909+00', '2025-06-01 15:05:50.030909+00');


--
-- Data for Name: shift_support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_assignments" ("id", "shift_id", "service_id", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('f298705a-d0f0-44bd-ba17-00d73cf1a712', 'f6e5f57f-23d5-449e-825b-0bad71119102', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2a2c2d11-07c0-4a5f-9229-6ea2084ded4b', 'f6e5f57f-23d5-449e-825b-0bad71119102', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('edb44524-2608-4534-840d-77d569af949c', 'f6e5f57f-23d5-449e-825b-0bad71119102', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('25f05439-cc88-4528-a4dd-3999eb131f93', 'f6e5f57f-23d5-449e-825b-0bad71119102', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('71f742c1-ef14-4fab-90cd-ae395adb33ce', 'f6e5f57f-23d5-449e-825b-0bad71119102', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d6c6de9f-f678-4c18-84ba-32847c803b66', 'f6e5f57f-23d5-449e-825b-0bad71119102', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('435f636f-ec17-447b-8fc2-87e2c877fb86', 'f6e5f57f-23d5-449e-825b-0bad71119102', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3315f4d3-50ae-4a81-b3b8-9ddc3dff7c44', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('59405f07-fd38-4a8b-9542-1cf1aa713d95', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('94caad51-a64a-4a06-bb62-de6136127850', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0a3bbb88-cca7-4221-996b-560ce53f56ce', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b7708856-2b36-4fb8-b1f2-44d78f8dc6e1', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('14f2cca4-b2eb-47de-8f19-984735c81672', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f65ca51f-b0a5-4e1d-9bf3-ae03ebd33214', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6968a374-74eb-4983-8374-441a9e44046e', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('13121238-b314-44f7-bb0e-e87d542d29d3', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c453693e-0f66-4771-8106-bc71eb9b6057', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f91b9e25-d9ff-4306-90ae-d651a2c1e1b2', '54d0bbe8-6cb1-461e-99bb-2d746affa629', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8d531c36-8ba9-43a3-b60d-f9828256d7ef', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b72a41ba-2b0d-46ac-b83b-60a5c8284df6', '54d0bbe8-6cb1-461e-99bb-2d746affa629', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('740e5a3a-a0f9-4361-8d53-c6be361e53b1', '54d0bbe8-6cb1-461e-99bb-2d746affa629', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4980791a-2477-4fcb-8813-8f04905838d9', '5980a43c-90e5-4721-92f9-d4f6ee516614', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6dd202ac-f20e-4073-b23b-0789a881f78f', '5980a43c-90e5-4721-92f9-d4f6ee516614', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2d2a7dd9-d70a-4b27-a00e-246479b1df93', '5980a43c-90e5-4721-92f9-d4f6ee516614', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ef441af9-7ae4-4c21-978f-dd747850e696', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('599c1a13-9041-452a-934f-5f73dd088c1b', '5980a43c-90e5-4721-92f9-d4f6ee516614', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('faef375a-cbbf-4bf4-9612-6a5760df91ed', '5980a43c-90e5-4721-92f9-d4f6ee516614', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('09da690b-2633-49fb-b280-6231a8462c53', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c74698ea-c138-43f2-a9e9-a4b182ee4c7a', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9ef3de7a-c2b2-4087-b3eb-723f0de11648', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('588b078f-5c98-48f2-92a8-69c7b87ec58f', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c5e2453d-dcc2-4968-afa6-f537498d3e71', '19ee13f3-d97b-45d6-8716-1243ad8ca120', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b55d4a6b-0e0f-48b0-a90e-e823e83acc24', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('75b94eb3-09ad-46c3-b7f1-8d7b61832cca', '19ee13f3-d97b-45d6-8716-1243ad8ca120', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('33e9e2b7-14b5-4156-83ef-2c51b77dc0ca', '19ee13f3-d97b-45d6-8716-1243ad8ca120', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('be534884-b972-4cc4-af67-1676e7fabf67', '1d0d0a5a-fbee-4c8e-a3cf-78c4eb1a003c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '08:00:00', '20:00:00', '#4285F4', '2025-06-01 14:51:20.424382+00', '2025-06-01 14:51:20.424382+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('bdcb4faa-f972-4ce1-b1bd-6cb76ffe4f37', '781a97d0-29bd-4e8b-8494-dca63156c45c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e22477b0-e4d6-4931-b241-d277f57907f4', '781a97d0-29bd-4e8b-8494-dca63156c45c', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0e6441a6-1726-42f1-9953-5c96fdcaf622', '781a97d0-29bd-4e8b-8494-dca63156c45c', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b1a3567f-ad7e-4699-8eb7-fc6ba667d44b', '781a97d0-29bd-4e8b-8494-dca63156c45c', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('98a3d8f3-31ec-4e4f-83c6-beafabcee1bd', '781a97d0-29bd-4e8b-8494-dca63156c45c', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4fc0dcae-8be1-4de1-a6b2-9db1da6614fc', '781a97d0-29bd-4e8b-8494-dca63156c45c', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3f9a7a28-c52d-457c-b4d7-5d8df21436ef', '781a97d0-29bd-4e8b-8494-dca63156c45c', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8153d00f-c5c7-4379-8d28-e71af9de1ff3', '9bc33d1c-2914-454c-bafc-e23374cc170b', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5f68a1e6-3bfe-4742-9280-ac574a2318f8', '9bc33d1c-2914-454c-bafc-e23374cc170b', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0595583a-e338-495e-8e04-4a2df22121e5', '9bc33d1c-2914-454c-bafc-e23374cc170b', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1c410148-1bb6-4fcf-8470-e141a92f7334', 'be379e15-5712-454f-9c1a-e429358828ec', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('70700b53-d159-4445-9f0a-5dd2deb26362', 'be379e15-5712-454f-9c1a-e429358828ec', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('46374378-33c8-474f-9155-9a4363e5a5f0', 'be379e15-5712-454f-9c1a-e429358828ec', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:00:00', '16:00:00', '#f4aa43', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('167bc59b-f039-4d48-935d-dbc61448c841', '9bc33d1c-2914-454c-bafc-e23374cc170b', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1e5ad0e5-65fd-4781-9301-895cd025b4d4', '9bc33d1c-2914-454c-bafc-e23374cc170b', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('100e01b3-1206-411a-bd14-39044aa74c7a', '9bc33d1c-2914-454c-bafc-e23374cc170b', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c9df56da-3107-4b8c-8cc6-1cd4eae1b5ed', '9bc33d1c-2914-454c-bafc-e23374cc170b', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('468a6a5f-c1af-4708-9925-af8938cb8029', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('012efa9b-8844-4a7e-a1d8-295206f30f9d', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3b3e4813-a3d9-4e4b-aad2-ff50f6289b35', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c05219a9-d7df-4b4a-a668-dbe43e9e71e7', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8672117f-bca8-4c22-9fe5-d8174547366c', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a7ffa92a-55fd-4f5d-a57a-5ee5b92bb223', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e9f80552-11f8-4b21-8b8f-9812a557733c', 'c0c4074f-a621-456e-b1dc-1fa598ee2a72', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('88d703b8-0767-413b-aee7-ebbee573d0ba', '485da1ff-6aba-4442-97c9-de053be8b587', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('99eef97d-b404-448c-bd78-658e88a9db27', '485da1ff-6aba-4442-97c9-de053be8b587', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('25d19cfe-1185-4e53-ad4c-0646314c89ef', '485da1ff-6aba-4442-97c9-de053be8b587', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fe1f6ed5-1047-4a5d-8724-8dcc5ab85075', '485da1ff-6aba-4442-97c9-de053be8b587', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b33f9ff3-2dc3-4874-86ea-15da2d1b3122', '485da1ff-6aba-4442-97c9-de053be8b587', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('99ca1e65-995e-4e24-bd3d-bea8cda5ccf3', '485da1ff-6aba-4442-97c9-de053be8b587', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('122850db-87b8-49ae-bcc7-6ee6a12bb2b2', '485da1ff-6aba-4442-97c9-de053be8b587', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8d6e071a-091c-4514-b5ed-1dd6be15c1e8', 'aceab786-878c-4e03-8933-2351d19e6ee6', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '08:00:00', '20:00:00', '#4285F4', '2025-05-31 16:54:19.752666+00', '2025-05-31 16:54:19.752666+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ad487902-d66a-4d40-b6f5-dc7e9457aa6d', 'cd388712-a45d-4584-a902-c168831a9e34', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '08:00:00', '20:00:00', '#4285F4', '2025-05-31 18:29:16.258854+00', '2025-05-31 18:29:16.258854+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cfa365fd-b114-4b6c-afc5-58f010e3fb96', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('efdfe484-1035-4e49-8b7d-5ec7cbd24f60', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0fdbfe5a-b8ea-4bae-bf89-cf5c5b070fac', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('12c15d88-8f8a-4c45-8000-d139db033f6c', 'cd7a5899-34e6-4616-8450-0ed8082a236e', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('76083dc5-da42-4614-abf0-8cb5b8d4bfa8', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('88c5e61a-4ef3-4899-9db0-b8d75674a8e6', 'cd7a5899-34e6-4616-8450-0ed8082a236e', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ab8c7c38-3558-401c-b04a-e5527aca782f', 'cd7a5899-34e6-4616-8450-0ed8082a236e', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b6aa6809-5e45-4d63-84f9-c186153c269e', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f9452cf4-7a39-456d-8cbd-e195583bb4f0', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('14acae7e-5244-49f1-a7b3-f516e26f4d61', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7d537637-1d3b-49fc-b627-d3fad7205fa7', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8ab5103f-512b-44ad-ac2d-2367deb94612', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b2947825-2626-4849-9eb3-e67aa962c444', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b984ba9d-cf6c-4fd6-be15-eb0c83e4ec0c', 'd442b266-e0fe-4b55-a143-3ef42a9bce28', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#4285F4', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('aa992541-d9cd-49c4-a1e8-7a6043ff7e2a', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cb74a98d-74d1-42af-aba6-68baf005c2ba', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('05cf03e4-69a6-4c14-8704-b95eeb33d0c6', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('edde1b57-bda2-4251-bb4d-6d21387e0aaa', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('347a26a5-03c6-4c85-bba1-30c16d94b081', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('10acec6b-a602-44d1-8e73-aeeaca0c19e8', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e5eaabda-1cdc-4d63-ba7e-0c6a85560f5d', '5c9f41a9-f20f-4ef5-8f28-c4fa502fed59', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d3035aa3-e310-4be0-ac09-f264c62e805d', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('adeb2cf3-df45-4534-a3b0-56cae3cbaa6c', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('09ae8425-fa5e-40c5-858d-fd1dd4e36416', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1cb7e056-72dd-4827-8c2a-0342462589b9', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('76fb7e13-1394-4458-8f7a-d4528c4c97e7', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b65698c0-6d16-4476-8043-c86393b4d4ed', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('62f71268-00e6-414e-8439-45d540d980f2', 'cc523e6c-087a-4456-8ebc-e84d734d0d16', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8c52549d-e8be-4d2a-ac55-5f1f0dda2c60', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e5ad38ef-cb48-45c6-bb27-26550d34122e', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c9b1be47-7448-4552-b776-2f6c919b7f9e', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e5db7979-3860-4bb6-b79a-480659909b7c', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('50f6d9d0-3966-43de-bae5-30e0b190902c', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('556f5160-6c4c-4808-853f-25eafe8b9da0', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9e710207-64af-4b05-b4e4-b2c4c31c12cf', '3f3954f2-7b0d-474f-b9de-f1721eb38e8e', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f0ba5272-7acc-4865-840c-c74e2e70551d', 'd357c573-8c18-42d0-a8cf-27f326454959', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a53c9075-e62b-41df-bee5-3fd8d4448dfe', 'd357c573-8c18-42d0-a8cf-27f326454959', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3764d9e4-5dee-4b9a-ace5-1b8e8d4c0e8c', 'd357c573-8c18-42d0-a8cf-27f326454959', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c140cabc-782c-4687-af04-ddbe3ad13a21', 'd357c573-8c18-42d0-a8cf-27f326454959', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('afac8b8b-5a5e-46b5-9a3d-6d3a7fe7efaa', 'd357c573-8c18-42d0-a8cf-27f326454959', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f65c0067-ac6a-4c0f-ac6c-45eaf228b1f5', 'd357c573-8c18-42d0-a8cf-27f326454959', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('67a5da3b-b539-4084-bcc4-878f59223006', 'd357c573-8c18-42d0-a8cf-27f326454959', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cf313e35-0e22-4472-9da1-ffe696556266', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e83c973e-c747-449e-b32e-67251191f137', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6351922a-e50c-4f58-aff7-9baec1cfa9df', '43f0073b-ab8d-4ed6-af91-4cc58492637d', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('232d4515-90d2-4643-b611-1fda123cfbdf', '43f0073b-ab8d-4ed6-af91-4cc58492637d', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('07e2eae1-98a4-4c1b-8953-212b5e2b92fe', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('aa61b7e8-ecbe-4668-95e0-ae78f955c77e', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('81862787-c462-45fa-bd51-2571ca7d0d6e', '43f0073b-ab8d-4ed6-af91-4cc58492637d', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('369c495b-c555-45c9-9f9a-0f26050796c4', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('01d6ec1f-855e-4dc4-a815-50735dcd2e0a', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4a63ce5b-5356-45d0-b479-4a904e08f063', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('20c58e8a-03d4-4fff-a4f9-71ffee8d3321', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('87f4ec37-20ce-458d-a725-bf845579cc3f', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('54164774-d38f-4307-ba7c-c92251e42f5d', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('dd4fa934-dd1e-4610-835b-9b6546462895', 'c72955ef-b280-4ce2-8df5-cb40b2b73a00', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0a7dd768-ba30-4435-b404-cfbba8472a6e', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8d8f310f-01df-4156-b15e-8d3f6e7f1349', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cd7e6ce9-0616-4a65-b13c-281ddd413957', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e32cc918-6b4a-413b-972d-24905a3ea92b', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e48b2ca2-f984-4839-a96b-5e1d4c776b3f', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6256eb96-94a1-471c-bd08-0ba84d359b4b', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a6ec4927-5a5b-44d5-90e8-3ae5458918f7', '2e383931-3092-4f7d-a2fc-7a0e8bfe18f2', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7b3d46dc-a829-4179-948e-8276d792a618', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a0645b01-e3d4-48a5-b95c-d8f3ccdba853', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('48fa0fa7-0472-4a9c-8ac1-43f5b8d19e65', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('74e9db3e-40d2-4854-bb9a-d3cfa171bdf6', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4940880c-0881-41a2-a145-b5fc308a1be5', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9003769c-fd12-4468-ba17-42b8c209f4b5', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8e347972-c649-4b22-acb9-a86a76193ca6', 'a42f9860-31ff-4d4a-aee3-c674ca0a0b77', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('39aa7717-93b9-49e5-9610-ad2f6dc6594c', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d4cee70d-55fc-48e3-a5b6-b1181042d347', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1572b65e-73e0-4fba-b286-d1cca6999330', '4bdba1e4-b27a-46e0-b753-08d6184884a8', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f5eda8ce-d6f3-489f-84df-2eb461034d9d', '4bdba1e4-b27a-46e0-b753-08d6184884a8', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('af299a1c-08fc-4087-8d3d-d2c2d918fcb4', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8a452de7-8e29-406e-aa7b-ff7e2103b0d8', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('afe8c6da-9097-4609-82e8-ab9562568032', '4bdba1e4-b27a-46e0-b753-08d6184884a8', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5e80161a-c565-4db9-a807-2941dc735af4', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '26c0891b-56c0-4346-8d53-de906aaa64c2', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('431aad02-7fdb-414c-b852-9661090a4e86', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d65832e4-8ac0-4213-b427-0d98cd51f628', '35d36c5b-f091-4fb9-af25-f74a37a6daea', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('eca32163-ae89-41c5-b683-f5366b2d9fbf', '35d36c5b-f091-4fb9-af25-f74a37a6daea', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('ced4c232-e320-468c-a7ee-a19986ddfc13', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8275d7f2-d429-4841-80c5-c936b9ee149b', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b18c5970-f9b6-4bc5-a355-6bd9ccd0c0ec', '35d36c5b-f091-4fb9-af25-f74a37a6daea', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: shift_support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_porter_assignments" ("id", "shift_support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('e760c138-59ac-49bd-b548-317f9b70c898', '71f742c1-ef14-4fab-90cd-ae395adb33ce', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('c55c13a0-36e7-4096-9ef4-bf09737c2dd8', '71f742c1-ef14-4fab-90cd-ae395adb33ce', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('5d227afa-1681-48ff-9c1b-9e2a9df3df9b', 'd6c6de9f-f678-4c18-84ba-32847c803b66', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('16ae114b-eb7b-4af6-8c07-dc3c08a850fa', 'd6c6de9f-f678-4c18-84ba-32847c803b66', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('13038525-6568-403a-b2e9-bff7b1209cb5', '435f636f-ec17-447b-8fc2-87e2c877fb86', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('bae5bad8-9547-4ad5-863f-05f8bd39d800', '435f636f-ec17-447b-8fc2-87e2c877fb86', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 14:22:16.150917+00', '2025-05-29 14:22:16.150917+00'),
	('f01a1fc3-1526-48ed-a4d6-40d0bbbd08d3', '1e5ad0e5-65fd-4781-9301-895cd025b4d4', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('0c57e831-ee8d-4f7c-9318-9ac0b10d9077', '1e5ad0e5-65fd-4781-9301-895cd025b4d4', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('2c89e7fd-33af-49f3-ad3d-f65c2a37414b', '100e01b3-1206-411a-bd14-39044aa74c7a', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('038147c2-e451-4cee-b676-12903d74fca3', '100e01b3-1206-411a-bd14-39044aa74c7a', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('3b392488-9cb5-4aef-bd22-4832818e843f', 'c9df56da-3107-4b8c-8cc6-1cd4eae1b5ed', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('2dd16dad-e8c1-48e6-9a0c-02d906c34feb', 'c9df56da-3107-4b8c-8cc6-1cd4eae1b5ed', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 14:49:43.084909+00', '2025-05-29 14:49:43.084909+00'),
	('c9095f69-937e-4213-b59f-09df87cdcf58', 'b7708856-2b36-4fb8-b1f2-44d78f8dc6e1', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('64141f58-a7e1-433a-8679-4a46f0212cdd', 'b7708856-2b36-4fb8-b1f2-44d78f8dc6e1', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('c3265f16-0bc4-4939-8d8d-21ef09a40e8e', '14f2cca4-b2eb-47de-8f19-984735c81672', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('62b04ef7-5e26-4c7e-b053-08bbf68ba019', '14f2cca4-b2eb-47de-8f19-984735c81672', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('4d4948f1-e0cb-4001-a7f0-e40de4d853cf', 'f65ca51f-b0a5-4e1d-9bf3-ae03ebd33214', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('90273a76-0d11-4be7-a102-085d52672fa3', 'f65ca51f-b0a5-4e1d-9bf3-ae03ebd33214', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 17:11:50.246091+00', '2025-05-29 17:11:50.246091+00'),
	('fdf7e979-052d-4b60-b096-bfca955271ba', '8672117f-bca8-4c22-9fe5-d8174547366c', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('069a9c08-da38-43bb-8987-f01b8f626c5c', '8672117f-bca8-4c22-9fe5-d8174547366c', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('56dda40c-5ef8-478f-92a0-d3887d90506e', 'a7ffa92a-55fd-4f5d-a57a-5ee5b92bb223', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('91efe6fe-b1a5-4ee9-9374-cb4163e4f3f8', 'a7ffa92a-55fd-4f5d-a57a-5ee5b92bb223', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('5113d6a4-f739-4baa-b595-1515aa4da9c3', 'e9f80552-11f8-4b21-8b8f-9812a557733c', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('9107205d-c331-4722-beb4-d9fe4f100946', 'e9f80552-11f8-4b21-8b8f-9812a557733c', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 17:32:16.33093+00', '2025-05-29 17:32:16.33093+00'),
	('42a47c60-8288-43e9-bcbd-93d0dae02783', '8d531c36-8ba9-43a3-b60d-f9828256d7ef', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('a01c2732-cc9f-4f03-88b5-7091277b7b68', '8d531c36-8ba9-43a3-b60d-f9828256d7ef', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('bb1cb60f-7453-43aa-86ba-aa0e21703520', 'b72a41ba-2b0d-46ac-b83b-60a5c8284df6', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('ef5eda57-a76e-4dd3-b590-c6f47bc9bdeb', 'b72a41ba-2b0d-46ac-b83b-60a5c8284df6', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('080bb632-681a-417d-987f-5bbd12eab905', '740e5a3a-a0f9-4361-8d53-c6be361e53b1', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('d1ae04ce-30f6-4d4d-980a-af7be2a88e88', '740e5a3a-a0f9-4361-8d53-c6be361e53b1', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-29 17:59:00.827285+00', '2025-05-29 17:59:00.827285+00'),
	('fc32257b-0e32-4c2e-ad17-b1458fd13392', 'b33f9ff3-2dc3-4874-86ea-15da2d1b3122', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('300892e2-4642-4b93-a370-44e6b86433b7', 'b33f9ff3-2dc3-4874-86ea-15da2d1b3122', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('1c601917-1fd3-41fc-b5f2-7b14fbef613a', '99ca1e65-995e-4e24-bd3d-bea8cda5ccf3', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('ff986631-b195-4edf-91ae-802ed999b2d3', '99ca1e65-995e-4e24-bd3d-bea8cda5ccf3', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('eeae74b6-8d47-4203-a2e4-49d12726700e', '122850db-87b8-49ae-bcc7-6ee6a12bb2b2', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('97da3af4-e38a-4ba6-8bd1-86fac28dc530', '122850db-87b8-49ae-bcc7-6ee6a12bb2b2', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-30 09:01:33.595623+00', '2025-05-30 09:01:33.595623+00'),
	('96d205be-4a55-4602-b41d-c93c278b9342', '599c1a13-9041-452a-934f-5f73dd088c1b', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('f2a43422-1330-4f7b-a64f-77e56e149341', '599c1a13-9041-452a-934f-5f73dd088c1b', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('4e54fd70-fa83-4c97-bd17-1d1988b0d05d', 'faef375a-cbbf-4bf4-9612-6a5760df91ed', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('9c9970ea-c241-44fb-9787-42541e9f17c6', 'faef375a-cbbf-4bf4-9612-6a5760df91ed', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('22b86c52-49df-48eb-bfc1-4f79182ce10d', '09da690b-2633-49fb-b280-6231a8462c53', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-30 11:13:19.855024+00', '2025-05-30 11:13:19.855024+00'),
	('686cbafe-c84e-4780-9ea7-c51a9138480c', 'b55d4a6b-0e0f-48b0-a90e-e823e83acc24', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('369533b6-a86e-4b07-a875-4655fe073543', '1c410148-1bb6-4fcf-8470-e141a92f7334', '394d8660-7946-4b31-87c9-b60f7e1bc294', '08:00:00', '16:00:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('7883cd73-5f47-485c-b615-098f6e0401bf', '1c410148-1bb6-4fcf-8470-e141a92f7334', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('24f3c3cf-6bc0-4e39-af65-b6c33841c144', '70700b53-d159-4445-9f0a-5dd2deb26362', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-28 08:54:44.361316+00', '2025-05-28 08:54:44.361316+00'),
	('1e19f4af-bad1-431b-93f5-34a10bc90e92', 'b55d4a6b-0e0f-48b0-a90e-e823e83acc24', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('de46c17b-9091-4985-9024-6bf6f06ab3a4', '75b94eb3-09ad-46c3-b7f1-8d7b61832cca', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('78c879b7-0488-49c6-8d00-acdbfc30feb8', '75b94eb3-09ad-46c3-b7f1-8d7b61832cca', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('cd0ffd1a-81f6-4a3e-87f2-3aa912917d74', '33e9e2b7-14b5-4156-83ef-2c51b77dc0ca', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('8ef58051-649d-4c69-9d75-cd435a41d75e', '33e9e2b7-14b5-4156-83ef-2c51b77dc0ca', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-31 16:55:37.384983+00', '2025-05-31 16:55:37.384983+00'),
	('b67f44bf-b540-4622-8dd0-5d64ba199d72', '76083dc5-da42-4614-abf0-8cb5b8d4bfa8', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('7bfabc9f-28ff-4ace-a3b1-a30b19e43cf8', '76083dc5-da42-4614-abf0-8cb5b8d4bfa8', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('4fecfc74-b27a-417a-9c27-6e92d5ebcbc2', '88c5e61a-4ef3-4899-9db0-b8d75674a8e6', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('a83f80a6-4378-4e97-bc07-1b04985b3707', '88c5e61a-4ef3-4899-9db0-b8d75674a8e6', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('df4c7726-7c7b-410e-bf1d-d0d6dbe6cfa1', 'ab8c7c38-3558-401c-b04a-e5527aca782f', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('f6d8bd99-d62c-4f6c-8585-8ad36653dfa1', 'ab8c7c38-3558-401c-b04a-e5527aca782f', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-05-31 18:29:45.143316+00', '2025-05-31 18:29:45.143316+00'),
	('ab771e26-d8c0-4c68-a56f-da5615e95537', '8ab5103f-512b-44ad-ac2d-2367deb94612', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('8becfa0b-cc11-4c98-a416-083e237a4dfe', '8ab5103f-512b-44ad-ac2d-2367deb94612', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('69e78d6f-dece-457c-a97c-e877631a16eb', 'b2947825-2626-4849-9eb3-e67aa962c444', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('082deb99-3250-4fa0-a5b2-48c4ebe79e63', 'b2947825-2626-4849-9eb3-e67aa962c444', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('d0214e47-d0c3-463a-b3fd-fca685f123fa', 'b984ba9d-cf6c-4fd6-be15-eb0c83e4ec0c', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('2c672c9b-5149-4a63-bbbd-dd5b01309b0c', 'b984ba9d-cf6c-4fd6-be15-eb0c83e4ec0c', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-06-01 14:51:41.189307+00', '2025-06-01 14:51:41.189307+00'),
	('e712257c-709b-4840-8a79-ed456c566be7', '98a3d8f3-31ec-4e4f-83c6-beafabcee1bd', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('01eb214b-2612-4079-a6a6-885d467c581e', '98a3d8f3-31ec-4e4f-83c6-beafabcee1bd', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('0fe1762e-47da-49a1-8bf0-7be920f68865', '4fc0dcae-8be1-4de1-a6b2-9db1da6614fc', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('7d88e4e3-d05b-4917-8cf4-86b1484e0b15', '4fc0dcae-8be1-4de1-a6b2-9db1da6614fc', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('fc54f2bc-e272-4c0d-bc49-236a39574e87', '3f9a7a28-c52d-457c-b4d7-5d8df21436ef', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '09:00:00', '17:00:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('3705aa55-b7c4-45e1-9f7d-c469548c4071', '3f9a7a28-c52d-457c-b4d7-5d8df21436ef', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '11:26:00', '14:27:00', '2025-06-01 15:19:12.249823+00', '2025-06-01 15:19:12.249823+00'),
	('c7dc58d2-6a29-41fd-b993-1307b0cb0b46', '347a26a5-03c6-4c85-bba1-30c16d94b081', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '07:00:00', '15:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('2af7ab55-c054-4bf6-90a6-95a5fe4e4923', '347a26a5-03c6-4c85-bba1-30c16d94b081', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '07:00:00', '15:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('5c61231f-8779-4d63-bcb1-dccc3076ec20', '10acec6b-a602-44d1-8e73-aeeaca0c19e8', '4377dd38-cf15-4de2-8347-0461ba6afff5', '07:00:00', '15:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('dc94f84c-e01a-44e5-893c-39c7e1117ac6', '10acec6b-a602-44d1-8e73-aeeaca0c19e8', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '07:00:00', '15:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('c5c4024e-637c-4fce-9338-45c2e727d0a1', 'e5eaabda-1cdc-4d63-ba7e-0c6a85560f5d', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('d06aa5e9-afd5-4131-9b75-1317206a7b75', 'e5eaabda-1cdc-4d63-ba7e-0c6a85560f5d', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('a78d3cf1-83d1-439c-bb52-23ad6fb3898b', 'e5eaabda-1cdc-4d63-ba7e-0c6a85560f5d', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('8ebd9bdc-7901-406a-8455-4994f34db806', 'e5eaabda-1cdc-4d63-ba7e-0c6a85560f5d', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-02 17:15:44.464231+00', '2025-06-02 17:15:44.464231+00'),
	('adee03dc-1e23-4b1c-81a9-e92a353aa5d5', '1cb7e056-72dd-4827-8c2a-0342462589b9', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('31cd4d58-22bb-4c58-accb-c59f197a72fd', '1cb7e056-72dd-4827-8c2a-0342462589b9', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('073fbcf3-efe8-4311-a4f0-32a8ff26d69c', '1cb7e056-72dd-4827-8c2a-0342462589b9', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('ecaecf65-af37-4095-9d2b-1f1b336ddce4', '1cb7e056-72dd-4827-8c2a-0342462589b9', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('a19b33cf-15f2-445e-b6ca-85d4be2c6f88', '76fb7e13-1394-4458-8f7a-d4528c4c97e7', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('19de5bec-e26f-4471-bee8-94b0c92cacc3', '76fb7e13-1394-4458-8f7a-d4528c4c97e7', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('7b12a138-2d33-4f7f-9baa-7855c34695cc', '62f71268-00e6-414e-8439-45d540d980f2', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 14:39:48.417602+00', '2025-06-03 14:39:48.417602+00'),
	('8b3a7a51-928b-4a2c-969e-3809ef5ba0bf', 'e5db7979-3860-4bb6-b79a-480659909b7c', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('b151ef21-dcfe-4338-bb2f-0c70f49e8048', 'e5db7979-3860-4bb6-b79a-480659909b7c', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('99499ba8-14ab-4207-a86b-051ad33e42d8', 'e5db7979-3860-4bb6-b79a-480659909b7c', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('6501cd63-1826-4a10-8b9a-f05ba4d488ea', 'e5db7979-3860-4bb6-b79a-480659909b7c', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('2afcf036-3750-4f00-a810-8bc39d714534', '50f6d9d0-3966-43de-bae5-30e0b190902c', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('d2225dd2-eb53-4262-8ca7-e43600f11f59', '50f6d9d0-3966-43de-bae5-30e0b190902c', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('474fb979-9900-437d-b3c9-34105e923146', '9e710207-64af-4b05-b4e4-b2c4c31c12cf', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 15:00:50.716958+00', '2025-06-03 15:00:50.716958+00'),
	('2a4dd352-cbd1-4949-8630-6cca81c07183', 'c140cabc-782c-4687-af04-ddbe3ad13a21', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('053d5a20-4c29-4680-806a-e220762b99cd', 'c140cabc-782c-4687-af04-ddbe3ad13a21', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('cb1cc4f2-3ed2-4263-b700-73d8c955b085', 'c140cabc-782c-4687-af04-ddbe3ad13a21', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('1f894c62-0fc2-4d4b-be50-8c3135d4f069', 'c140cabc-782c-4687-af04-ddbe3ad13a21', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('07736a97-bd52-44d1-bbbb-088eac597698', 'afac8b8b-5a5e-46b5-9a3d-6d3a7fe7efaa', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('5442d2be-ee0f-4f9f-bae5-55d6b5878d92', 'afac8b8b-5a5e-46b5-9a3d-6d3a7fe7efaa', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('9d16957f-25a1-45ba-86aa-8bc5897f6d2b', '67a5da3b-b539-4084-bcc4-878f59223006', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 15:01:43.680997+00', '2025-06-03 15:01:43.680997+00'),
	('97bb63b7-6be9-4ba5-b70f-8e16b7bd1cad', '232d4515-90d2-4643-b611-1fda123cfbdf', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('da7f4584-4d08-405e-8df1-4f8acbabac6a', '232d4515-90d2-4643-b611-1fda123cfbdf', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('761e861c-370e-4199-8ad5-ea394db1d7a7', '232d4515-90d2-4643-b611-1fda123cfbdf', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('8f08b45f-88ba-4cc3-a247-abad222cee52', '232d4515-90d2-4643-b611-1fda123cfbdf', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('b7d10a1b-fa00-4e50-a9d5-17af5a791530', '07e2eae1-98a4-4c1b-8953-212b5e2b92fe', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('faaa0dae-eb5d-4d7a-9aad-dc7d1465190a', '07e2eae1-98a4-4c1b-8953-212b5e2b92fe', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('33408b8d-2db2-4ee1-8b8d-b9cb0fbec14c', '81862787-c462-45fa-bd51-2571ca7d0d6e', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 15:05:26.002298+00', '2025-06-03 15:05:26.002298+00'),
	('5c97a88b-6907-4a1c-9709-ff0e27db6f7a', '20c58e8a-03d4-4fff-a4f9-71ffee8d3321', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('07e648ab-f120-4315-b473-3e5ebd99d8a1', '20c58e8a-03d4-4fff-a4f9-71ffee8d3321', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('20dcaf0d-2c40-48ea-a42a-974d33f1e7ed', '20c58e8a-03d4-4fff-a4f9-71ffee8d3321', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('5aff9935-ddee-48b6-a447-5dc158ddd3a4', '20c58e8a-03d4-4fff-a4f9-71ffee8d3321', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('c9b0ff4b-702b-4cca-a62a-af27d6100a25', '87f4ec37-20ce-458d-a725-bf845579cc3f', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('021a6bce-9441-472e-8dae-10b523d7e51d', '87f4ec37-20ce-458d-a725-bf845579cc3f', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('235e3062-e919-41c9-aacc-222de56bf31b', 'dd4fa934-dd1e-4610-835b-9b6546462895', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 15:06:00.602511+00', '2025-06-03 15:06:00.602511+00'),
	('8a2e2cb6-775b-4543-bc78-ae0282e785c4', 'e32cc918-6b4a-413b-972d-24905a3ea92b', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('5734f602-234c-4f1f-9a3c-695352905c0b', 'e32cc918-6b4a-413b-972d-24905a3ea92b', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('a123cc9a-a458-4a9e-b2b0-cb89d3d20a85', 'e32cc918-6b4a-413b-972d-24905a3ea92b', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('2ab9803d-36ba-4919-a6da-6653f7eb6a93', 'e32cc918-6b4a-413b-972d-24905a3ea92b', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('3200fc28-7f32-4ddb-b970-1c8b9bb20718', 'e48b2ca2-f984-4839-a96b-5e1d4c776b3f', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('b94fcd4e-b4e8-465c-b93e-65d995bb23a7', 'e48b2ca2-f984-4839-a96b-5e1d4c776b3f', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('ef7436e9-fbfc-4172-9166-e9ee1ef8c948', 'a6ec4927-5a5b-44d5-90e8-3ae5458918f7', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 15:06:42.096088+00', '2025-06-03 15:06:42.096088+00'),
	('64e80346-eeaa-4db7-abb2-92df0562a8e6', '74e9db3e-40d2-4854-bb9a-d3cfa171bdf6', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('2060fb20-776f-46a8-a005-b30946f28839', '74e9db3e-40d2-4854-bb9a-d3cfa171bdf6', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('25f37bd6-55f7-4326-a394-3901ee5596ce', '74e9db3e-40d2-4854-bb9a-d3cfa171bdf6', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('ec3ba0ca-2750-4a95-9756-5723772eeef3', '74e9db3e-40d2-4854-bb9a-d3cfa171bdf6', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('c706a7fe-0250-4721-a14f-e672f825709d', '4940880c-0881-41a2-a145-b5fc308a1be5', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('204a7e32-51e0-42fa-9c7d-fd1667e124a6', '4940880c-0881-41a2-a145-b5fc308a1be5', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('49c2d75f-f499-4fa9-87f8-22a2764be675', '8e347972-c649-4b22-acb9-a86a76193ca6', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 15:44:53.654287+00', '2025-06-03 15:44:53.654287+00'),
	('93293ed2-f7f9-457f-8b57-cdf697942d9c', 'f5eda8ce-d6f3-489f-84df-2eb461034d9d', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('446e415b-cc6e-4cdd-a34b-1941ffc8fb1c', 'f5eda8ce-d6f3-489f-84df-2eb461034d9d', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('c629409e-2c7a-4f0b-b434-8169ca031fd7', 'f5eda8ce-d6f3-489f-84df-2eb461034d9d', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('d33364b8-950f-4dd7-8062-aa709fb32476', 'f5eda8ce-d6f3-489f-84df-2eb461034d9d', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('e569d12f-fa7e-4181-af22-0e8b71c5cb67', 'af299a1c-08fc-4087-8d3d-d2c2d918fcb4', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('472c72e6-3c79-4ab7-8356-4ddf0956dbc0', 'af299a1c-08fc-4087-8d3d-d2c2d918fcb4', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('d18c7db3-3cf6-40d0-a70d-ae6e0dadcda5', 'afe8c6da-9097-4609-82e8-ab9562568032', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 15:55:16.361515+00', '2025-06-03 15:55:16.361515+00'),
	('81d25131-ff8d-4e24-ac1a-4b53fd740331', 'eca32163-ae89-41c5-b683-f5366b2d9fbf', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('714dda46-3491-454b-a045-dae10551af18', 'eca32163-ae89-41c5-b683-f5366b2d9fbf', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('a737d38d-2453-4fd0-ab40-5dc08fc187bc', 'eca32163-ae89-41c5-b683-f5366b2d9fbf', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('9daa8128-bfd4-47b4-9cc5-87b7b0419503', 'eca32163-ae89-41c5-b683-f5366b2d9fbf', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('d8e7fe68-7f49-4417-b1d6-0bbbb66e5bc9', 'ced4c232-e320-468c-a7ee-a19986ddfc13', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('b8ae3e5c-90ea-470d-8842-46f1f06d5e7c', 'ced4c232-e320-468c-a7ee-a19986ddfc13', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00'),
	('a16b6494-f776-48ae-9953-8609ba8d514b', 'b18c5970-f9b6-4bc5-a355-6bd9ccd0c0ec', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-03 16:20:20.646495+00', '2025-06-03 16:20:20.646495+00');


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

INSERT INTO "public"."task_items" ("id", "task_type_id", "name", "description", "created_at", "updated_at", "is_regular") VALUES
	('e6068d5d-4bc5-4358-8bae-ed23759dc733', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen F Size', NULL, '2025-05-22 11:25:09.159861+00', '2025-05-22 11:25:09.159861+00', false),
	('8058ea70-75c8-4e46-a56f-7490a48cd4f5', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed (Complete)', NULL, '2025-05-22 12:00:44.450407+00', '2025-05-22 12:00:44.450407+00', false),
	('a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', 'b864ed57-5547-404e-9459-1641a030974e', 'Bed Frame', NULL, '2025-05-22 12:00:52.076144+00', '2025-05-22 12:00:52.076144+00', false),
	('93150478-e3b7-4315-bfb2-8f44a78b2f77', 'b864ed57-5547-404e-9459-1641a030974e', 'Mattress', NULL, '2025-05-24 15:17:23.893487+00', '2025-05-24 15:17:23.893487+00', false),
	('532b14f0-042a-4ddf-bc7d-cb95ff298132', 'bf94a068-cb8f-4a68-b053-14135b4ad6cd', 'Incubator', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:17:40.681145+00', false),
	('f18bf0ce-835e-4d9d-92d0-119222a56f5e', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen D Size', NULL, '2025-05-24 15:18:21.251002+00', '2025-05-24 15:18:21.251002+00', false),
	('377506db-7bf7-44e8-bc8f-c7c316914579', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Entenox E Size', NULL, '2025-05-24 15:18:39.13243+00', '2025-05-24 15:18:39.13243+00', false),
	('14446938-25cd-4655-ad84-dbb7db871f28', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Bed', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:50.766252+00', false),
	('68e8e006-79dc-4d5f-aed0-20755d53403b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Wheelchair', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:56.015534+00', false),
	('5c269ddd-7abd-4d10-a0b3-d93fccb4f6de', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Trolly', NULL, '2025-05-24 15:19:02.302787+00', '2025-05-24 15:19:02.302787+00', false),
	('934256c2-fbe5-480b-a0ac-897d9d5b9358', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Urine Sample', NULL, '2025-05-24 15:19:41.366895+00', '2025-05-24 15:19:41.366895+00', false),
	('5c0c9e25-ae34-4872-8696-4c4ce6e76112', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Multiple Samples', NULL, '2025-05-24 15:19:53.083235+00', '2025-05-24 15:19:53.083235+00', false),
	('e5e84800-eb11-4889-bb97-39ea75ef5190', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Blood', NULL, '2025-05-24 15:23:49.29882+00', '2025-05-24 15:23:49.29882+00', false),
	('ee6c4e53-bcfa-4271-b0d5-dc61a5d0427c', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Albumen', NULL, '2025-05-24 15:23:58.062632+00', '2025-05-24 15:23:58.062632+00', false),
	('b55609c2-9be4-4851-ad2c-dfc199795298', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Platelets', NULL, '2025-05-24 15:24:05.948941+00', '2025-05-24 15:24:05.948941+00', false),
	('b8fed973-ab36-4d31-801a-7ebbde95413a', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed (Complete)', NULL, '2025-05-24 15:27:01.862194+00', '2025-05-24 15:27:01.862194+00', false),
	('81e0d17c-740a-4a00-9727-81d222f96234', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Bed Frame', NULL, '2025-05-24 15:27:10.580403+00', '2025-05-24 15:27:10.580403+00', false),
	('deab62e1-ae79-4f77-ab65-0a04c1f040a1', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Mattress', NULL, '2025-05-24 15:27:17.680461+00', '2025-05-24 15:27:17.680461+00', false),
	('1933a5d4-e02d-4301-b580-a0fdbdbfb21d', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Walk', NULL, '2025-05-25 09:51:59.07475+00', '2025-05-25 09:51:59.07475+00', false),
	('be835d6f-62c6-48bf-ae5f-5257e097349b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Rose Cottage', NULL, '2025-05-27 15:50:47.505753+00', '2025-05-27 15:50:47.505753+00', false),
	('dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Blood Sample', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-29 16:36:07.126107+00', true),
	('5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen E Size', NULL, '2025-05-24 15:18:10.625096+00', '2025-05-29 17:55:20.230293+00', true);


--
-- Data for Name: shift_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('eab0e491-0386-40e6-a28e-a214592f4718', 'be379e15-5712-454f-9c1a-e429358828ec', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-05-28 13:47:26.082777+00', '2025-05-28 13:47:26.082777+00', '2025-05-28T14:47:00', '2025-05-28T14:48:00', '2025-05-28T15:07:00'),
	('d8937dae-9b65-4c18-b2b2-aa875c3d99b8', 'be379e15-5712-454f-9c1a-e429358828ec', '81e0d17c-740a-4a00-9727-81d222f96234', NULL, 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-28 13:47:54.071702+00', '2025-05-28 13:47:54.071702+00', '2025-05-28T14:47:00', '2025-05-28T14:48:00', '2025-05-28T15:07:00'),
	('9722e7b8-291b-49ff-919c-4f44905b650d', 'be379e15-5712-454f-9c1a-e429358828ec', '5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', '75ff4301-3c45-44c5-bd93-1b3a471baaeb', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-05-28 13:48:28.11982+00', '2025-05-29 08:52:00.278251+00', '2025-05-28T14:48:00', '2025-05-28T14:49:00', '2025-05-28T15:08:00'),
	('22814230-fa00-4206-8c40-12312d13caa5', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', '786d6d23-69b9-433e-92ed-938806cb10a8', '969a27a7-f5e5-4c23-b018-128aa2000b97', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'completed', '2025-05-29 17:28:28.038505+00', '2025-05-29 17:28:28.038505+00', '2025-05-29T18:27:00', '2025-05-29T18:28:00', '2025-05-29T18:47:00'),
	('e2a48bd5-e14d-4c39-980b-047d359846f3', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '786d6d23-69b9-433e-92ed-938806cb10a8', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-05-29 17:25:38.07692+00', '2025-05-29 17:28:43.629128+00', '18:25', '18:26', '18:45'),
	('5222c466-afc2-4b51-9981-7a4c9149b5a5', '252c4263-7c4d-47c1-9fd3-62b3ec4b5046', '5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', NULL, 'acb46743-a8c8-4cf5-bc85-4b9480f1862e', NULL, 'completed', '2025-05-29 17:56:34.546219+00', '2025-05-29 17:56:34.546219+00', '2025-05-29T18:56:00', '2025-05-29T18:57:00', '2025-05-29T19:16:00'),
	('353c0f38-db0c-4611-bd10-2c4c4a819f83', '485da1ff-6aba-4442-97c9-de053be8b587', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '8eaa9194-b164-4cb4-a15c-956299ff28c5', '81c30d93-8712-405c-ac5e-509d48fd9af9', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-05-30 09:02:26.178348+00', '2025-05-30 09:02:26.178348+00', '2025-05-30T10:02:00', '2025-05-30T10:03:00', '2025-05-30T10:22:00'),
	('e2e4b917-daac-4d21-92bd-c4aca4c2edbb', '485da1ff-6aba-4442-97c9-de053be8b587', 'f18bf0ce-835e-4d9d-92d0-119222a56f5e', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'acb46743-a8c8-4cf5-bc85-4b9480f1862e', NULL, 'completed', '2025-05-30 09:03:11.642859+00', '2025-05-30 09:03:11.642859+00', '2025-05-30T10:02:00', '2025-05-30T10:03:00', '2025-05-30T10:22:00'),
	('4d5805f5-e1bc-4efd-a839-c0dfa3e5a235', '485da1ff-6aba-4442-97c9-de053be8b587', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '8eaa9194-b164-4cb4-a15c-956299ff28c5', '19b02bca-1dc6-4d00-b04d-a7e141a04870', '9056ee14-242b-4208-a87d-fc59d24d442c', 'pending', '2025-05-30 09:04:47.378574+00', '2025-05-30 09:04:59.345478+00', '2025-05-30T10:04:00', '2025-05-30T10:05:00', '2025-05-30T10:24:00'),
	('0b57dc93-96e3-423e-bc07-7c8062f53942', '485da1ff-6aba-4442-97c9-de053be8b587', '5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', 'ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'acb46743-a8c8-4cf5-bc85-4b9480f1862e', '1ae5c936-b74c-453e-a614-42b983416e40', 'completed', '2025-05-30 09:05:28.260733+00', '2025-05-30 09:05:28.260733+00', '2025-05-30T10:05:00', '2025-05-30T10:06:00', '2025-05-30T10:25:00'),
	('f6c10416-44d7-4a5a-b9fc-dfd827638d7c', '485da1ff-6aba-4442-97c9-de053be8b587', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-05-30 11:10:28.391686+00', '2025-05-30 11:10:28.391686+00', '2025-05-30T12:10:00', '2025-05-30T12:11:00', '2025-05-30T12:30:00'),
	('ce1a55c5-b0e5-416a-be9c-1d81e29b2eba', '485da1ff-6aba-4442-97c9-de053be8b587', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4e87f01b-5196-47c4-b424-4cfdbe7fb385', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-05-30 11:11:15.491465+00', '2025-05-30 11:11:15.491465+00', '2025-05-30T12:11:00', '2025-05-30T12:12:00', '2025-05-30T12:31:00'),
	('339b7728-9c53-4eb1-8037-3b256c5534b6', '5980a43c-90e5-4721-92f9-d4f6ee516614', 'f18bf0ce-835e-4d9d-92d0-119222a56f5e', 'ecc67de0-fecc-4c93-b9da-445c3cef4ea4', 'acb46743-a8c8-4cf5-bc85-4b9480f1862e', '571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'completed', '2025-05-30 11:15:11.001473+00', '2025-05-30 11:15:18.633547+00', '2025-05-30T12:14:00', '2025-05-30T12:15:00', '2025-05-30T12:34:00');


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
	('e4a761cc-ad70-4925-8295-35c3fec29cc4', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_night'),
	('f864cc63-5b10-4679-8355-1c1bde5ffda0', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '20:00:00', '04:00:00', '#FBBC05', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'week_night'),
	('2c67f62c-5bf4-4805-9ac3-e5e5a451bd85', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '20:00:00', '04:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_night'),
	('f9596013-1567-4c31-ae8e-ebb8737e0802', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '20:00:00', '08:00:00', '#673AB7', '2025-05-25 06:50:10.906802+00', '2025-05-25 06:50:10.906802+00', 'weekend_night'),
	('a8445e2f-ded7-45dd-a696-6b5b257764ad', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '09:00:00', '17:00:00', '#EA4335', '2025-05-25 06:50:10.906802+00', '2025-05-26 09:03:53.478545+00', 'weekend_day'),
	('56356547-809d-4c8f-9bbd-bd78398d1d7a', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-26 09:04:19.954505+00', 'weekend_day'),
	('e3eab35f-e5b5-4001-a8f5-733314f7587e', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '08:00:00', '16:00:00', '#34A853', '2025-05-25 06:50:10.906802+00', '2025-05-26 10:12:24.468889+00', 'week_day'),
	('be438b48-ecae-48ac-a9ff-b63a7f45a061', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '08:00:00', '16:00:00', '#4285F4', '2025-05-25 06:50:10.906802+00', '2025-05-26 10:16:55.703084+00', 'week_day');


--
-- Data for Name: support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."support_service_porter_assignments" ("id", "support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('ec6e6a94-b776-4bca-97af-09168c4b6354', '56356547-809d-4c8f-9bbd-bd78398d1d7a', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '14:58:00', '22:58:00', '2025-05-26 09:04:20.014261+00', '2025-05-26 09:04:20.014261+00'),
	('d988cc25-9301-41b1-bcb1-7876d68fa11b', 'e3eab35f-e5b5-4001-a8f5-733314f7587e', '786d6d23-69b9-433e-92ed-938806cb10a8', '15:12:00', '16:12:00', '2025-05-26 10:12:24.52429+00', '2025-05-26 10:12:24.52429+00'),
	('a68dbdbc-95f0-4e0f-a85e-34b852f1a6ef', 'be438b48-ecae-48ac-a9ff-b63a7f45a061', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '15:16:00', '16:16:00', '2025-05-26 10:16:55.773306+00', '2025-05-26 10:16:55.773306+00');


--
-- Data for Name: task_item_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_item_department_assignments" ("id", "task_item_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('ca6ab4d5-30dc-4cc9-8430-d5869da60a2d', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', true, false, '2025-05-24 15:21:51.189039+00'),
	('0d5d2df0-cc4d-4a68-829a-53fa3304c1e5', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', '969a27a7-f5e5-4c23-b018-128aa2000b97', true, false, '2025-05-24 15:22:08.265118+00'),
	('b081b8d8-27e2-4538-9d83-b1512f9f77ff', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', true, false, '2025-05-24 15:25:45.227716+00'),
	('1c92bb0d-1130-4e11-bf56-b9bfc1f6a49d', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', true, false, '2025-05-27 16:10:54.167911+00');


--
-- Data for Name: task_type_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_type_department_assignments" ("id", "task_type_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('ceaa8539-8fd6-4954-8c00-2f8aea4bb3a6', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '9056ee14-242b-4208-a87d-fc59d24d442c', false, true, '2025-05-24 12:33:59.810318+00'),
	('bfda15f6-809b-436f-abd2-d2c16dd7663c', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '81c30d93-8712-405c-ac5e-509d48fd9af9', true, false, '2025-05-24 15:22:58.114521+00'),
	('100f3cf6-3d37-4e48-90f3-c01b7874856b', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', true, false, '2025-05-24 15:23:36.64394+00'),
	('54743734-1466-4d1d-a90b-c01061983517', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'acb46743-a8c8-4cf5-bc85-4b9480f1862e', true, false, '2025-05-29 17:55:54.943147+00');


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
