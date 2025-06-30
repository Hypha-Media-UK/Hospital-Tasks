

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
  RAISE NOTICE '%', v_debug_info;

  -- Copy area cover assignments from defaults to shift
  FOR r_area_assignment IN
    SELECT * FROM default_area_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := 'Processing area cover assignment: ' || r_area_assignment.id || ' for department: ' || r_area_assignment.department_id;
    RAISE NOTICE '%', v_debug_info;

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
    v_debug_info := 'Created shift_area_cover_assignment: ' || v_area_cover_assignment_id;
    RAISE NOTICE '%', v_debug_info;

    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count
    FROM default_area_cover_porter_assignments
    WHERE default_area_cover_assignment_id = v_default_area_cover_id;

    -- Add to debug info
    v_debug_info := 'Found ' || v_porter_count || ' porter assignments to copy for area cover';
    RAISE NOTICE '%', v_debug_info;

    -- Copy porter assignments for this area cover
    FOR r_area_porter IN
      SELECT * FROM default_area_cover_porter_assignments
      WHERE default_area_cover_assignment_id = v_default_area_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := 'Processing area porter assignment: ' || r_area_porter.id || ' for porter: ' || r_area_porter.porter_id;
      RAISE NOTICE '%', v_debug_info;

      -- Insert the porter assignment
      INSERT INTO shift_area_cover_porter_assignments (
        shift_area_cover_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_area_cover_assignment_id, r_area_porter.porter_id,
        r_area_porter.start_time, r_area_porter.end_time
      );

      -- Add to debug info
      v_debug_info := 'Successfully created area porter assignment for porter_id: ' || r_area_porter.porter_id;
      RAISE NOTICE '%', v_debug_info;
    END LOOP;
  END LOOP;

  -- Copy service cover assignments from defaults to shift
  FOR r_service_assignment IN
    SELECT * FROM default_service_cover_assignments WHERE shift_type = p_shift_type
  LOOP
    -- Add to debug info
    v_debug_info := 'Processing service cover assignment: ' || r_service_assignment.id || ' for service: ' || r_service_assignment.service_id;
    RAISE NOTICE '%', v_debug_info;

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
    v_debug_info := 'Created shift_support_service_assignment: ' || v_service_cover_assignment_id;
    RAISE NOTICE '%', v_debug_info;

    -- Count how many porter assignments we should copy
    SELECT COUNT(*) INTO v_porter_count
    FROM default_service_cover_porter_assignments
    WHERE default_service_cover_assignment_id = v_default_service_cover_id;

    -- Add to debug info
    v_debug_info := 'Found ' || v_porter_count || ' porter assignments to copy for service cover';
    RAISE NOTICE '%', v_debug_info;

    -- Copy porter assignments for this service cover
    FOR r_service_porter IN
      SELECT * FROM default_service_cover_porter_assignments
      WHERE default_service_cover_assignment_id = v_default_service_cover_id
    LOOP
      -- Add to debug info
      v_debug_info := 'Processing service porter assignment: ' || r_service_porter.id || ' for porter: ' || r_service_porter.porter_id;
      RAISE NOTICE '%', v_debug_info;

      -- Insert the porter assignment
      INSERT INTO shift_support_service_porter_assignments (
        shift_support_service_assignment_id, porter_id, start_time, end_time
      ) VALUES (
        v_service_cover_assignment_id, r_service_porter.porter_id,
        r_service_porter.start_time, r_service_porter.end_time
      );

      -- Add to debug info
      v_debug_info := 'Successfully created service porter assignment for porter_id: ' || r_service_porter.porter_id;
      RAISE NOTICE '%', v_debug_info;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Completed copy_defaults_to_shift for shift_id: %', p_shift_id;
END;
$$;


ALTER FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."copy_defaults_to_shift"("p_shift_id" "uuid", "p_shift_type" character varying) IS 'Copies default area cover and service cover assignments to a new shift. 
This FIXED version includes proper porter assignment copying and enhanced debugging to ensure porter assignments 
are properly copied from default_area_cover_porter_assignments to shift_area_cover_porter_assignments
and from default_service_cover_porter_assignments to shift_support_service_porter_assignments.';



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


CREATE TABLE IF NOT EXISTS "public"."buildings" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0,
    "porter_serviced" boolean DEFAULT false,
    "abbreviation" character varying(2)
);


ALTER TABLE "public"."buildings" OWNER TO "postgres";


COMMENT ON COLUMN "public"."buildings"."porter_serviced" IS 'Indicates whether this building requires porter service';



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


CREATE TABLE IF NOT EXISTS "public"."department_task_assignments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "department_id" "uuid",
    "task_type_id" "uuid",
    "task_item_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."department_task_assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."departments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "building_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_frequent" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "sort_order" integer DEFAULT 0,
    "color" character varying(20) DEFAULT '#CCCCCC'::character varying
);


ALTER TABLE "public"."departments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."departments"."color" IS 'Department color used for consistent visual representation across the application';



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
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "agreed_absence" character varying(15)
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



CREATE TABLE IF NOT EXISTS "public"."shift_porter_absences" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "absence_reason" character varying(15),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shift_porter_absences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_porter_pool" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "porter_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_supervisor" boolean DEFAULT false
);


ALTER TABLE "public"."shift_porter_pool" OWNER TO "postgres";


COMMENT ON COLUMN "public"."shift_porter_pool"."is_supervisor" IS 'Indicates if this porter entry represents the shift supervisor';



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
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "agreed_absence" character varying(15)
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



CREATE TABLE IF NOT EXISTS "public"."shifts" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "supervisor_id" "uuid" NOT NULL,
    "shift_type" "text" NOT NULL,
    "start_time" timestamp with time zone DEFAULT "now"() NOT NULL,
    "end_time" timestamp with time zone,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "shift_date" "date" NOT NULL,
    CONSTRAINT "shifts_shift_type_check" CHECK (("shift_type" = ANY (ARRAY['week_day'::"text", 'week_night'::"text", 'weekend_day'::"text", 'weekend_night'::"text"])))
);


ALTER TABLE "public"."shifts" OWNER TO "postgres";


COMMENT ON COLUMN "public"."shifts"."shift_date" IS 'The date this shift is scheduled for (YYYY-MM-DD format)';



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



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_department_id_key" UNIQUE ("department_id");



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."shift_porter_absences"
    ADD CONSTRAINT "shift_porter_absences_pkey" PRIMARY KEY ("id");



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



CREATE INDEX "idx_shift_porter_pool_supervisor" ON "public"."shift_porter_pool" USING "btree" ("shift_id", "is_supervisor");



CREATE INDEX "idx_shifts_is_active" ON "public"."shifts" USING "btree" ("is_active");



CREATE INDEX "idx_shifts_shift_date" ON "public"."shifts" USING "btree" ("shift_date");



CREATE INDEX "idx_shifts_supervisor_id" ON "public"."shifts" USING "btree" ("supervisor_id");



CREATE INDEX "shift_area_cover_assignments_department_id_idx" ON "public"."shift_area_cover_assignments" USING "btree" ("department_id");



CREATE INDEX "shift_area_cover_assignments_shift_id_idx" ON "public"."shift_area_cover_assignments" USING "btree" ("shift_id");



CREATE INDEX "shift_area_cover_porter_assignments_porter_id_idx" ON "public"."shift_area_cover_porter_assignments" USING "btree" ("porter_id");



CREATE INDEX "shift_area_cover_porter_assignments_shift_area_cover_id_idx" ON "public"."shift_area_cover_porter_assignments" USING "btree" ("shift_area_cover_assignment_id");



CREATE INDEX "shift_porter_absences_porter_id_idx" ON "public"."shift_porter_absences" USING "btree" ("porter_id");



CREATE INDEX "shift_porter_absences_shift_id_idx" ON "public"."shift_porter_absences" USING "btree" ("shift_id");



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



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_department_id_fkey" FOREIGN KEY ("department_id") REFERENCES "public"."departments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_task_item_id_fkey" FOREIGN KEY ("task_item_id") REFERENCES "public"."task_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."department_task_assignments"
    ADD CONSTRAINT "department_task_assignments_task_type_id_fkey" FOREIGN KEY ("task_type_id") REFERENCES "public"."task_types"("id") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."shift_porter_absences"
    ADD CONSTRAINT "shift_porter_absences_porter_id_fkey" FOREIGN KEY ("porter_id") REFERENCES "public"."staff"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_porter_absences"
    ADD CONSTRAINT "shift_porter_absences_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."shifts"("id") ON DELETE CASCADE;



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



CREATE POLICY "Enable delete access for authenticated users" ON "public"."shift_porter_absences" FOR DELETE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Enable insert access for authenticated users" ON "public"."shift_porter_absences" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Enable read access for all users" ON "public"."shift_porter_absences" FOR SELECT USING (true);



CREATE POLICY "Enable update access for authenticated users" ON "public"."shift_porter_absences" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));





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



GRANT ALL ON TABLE "public"."department_task_assignments" TO "anon";
GRANT ALL ON TABLE "public"."department_task_assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."department_task_assignments" TO "service_role";



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



GRANT ALL ON TABLE "public"."shift_porter_absences" TO "anon";
GRANT ALL ON TABLE "public"."shift_porter_absences" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_porter_absences" TO "service_role";



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
	('fa5c9416-2b70-4b81-9f54-7ebaaac411c0', 'GMT', '24h', '2025-05-28 14:07:30.519927+00', '2025-05-28 14:07:27.858+00'),
	('ad3c2d3b-d941-4116-bb68-fd2c94e8c35b', 'GMT', '24h', '2025-06-24 23:48:58.973734+00', '2025-06-24 23:48:58.594+00'),
	('7fa2036f-59f1-4016-88f5-4f6ec8d2d7b0', 'Europe/London', '24h', '2025-06-24 23:49:38.401658+00', '2025-06-24 23:49:38.059+00'),
	('c661a2b5-4752-409f-ae92-b5b7fc9cf6de', 'UTC', '24h', '2025-06-25 01:12:08.219221+00', '2025-06-25 01:12:08.219221+00'),
	('4f91540d-0e3c-4369-926f-f83648c383ef', 'GMT', '24h', '2025-06-25 01:28:04.028417+00', '2025-06-25 01:28:03.961+00'),
	('250f5d63-f85c-4c17-95df-06761d6590c3', 'GMT', '24h', '2025-06-25 01:28:35.954856+00', '2025-06-25 01:28:35.902+00'),
	('7f000644-e6f6-4acf-a107-22526bed0266', 'GMT', '24h', '2025-06-25 01:29:52.529878+00', '2025-06-25 01:29:52.46+00'),
	('2643e1b2-763b-49b9-b6e5-8bc5dcd40f7a', 'GMT', '24h', '2025-06-26 00:07:43.614196+00', '2025-06-26 00:07:43.404+00'),
	('23828620-07bb-4660-821b-fd3c9253b8cf', 'GMT', '24h', '2025-06-26 22:11:14.068061+00', '2025-06-26 22:11:13.794+00');


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."buildings" ("id", "name", "address", "created_at", "updated_at", "sort_order", "porter_serviced", "abbreviation") VALUES
	('b4891ac9-bb9c-4c63-977d-038890607b98', 'Harstshead', NULL, '2025-05-22 10:41:06.907057+00', '2025-06-30 18:01:33.422336+00', 10, true, 'HH'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ladysmith Building', '123 Medical Drive', '2025-05-22 10:30:30.870153+00', '2025-06-30 18:01:53.42617+00', 30, true, 'LS'),
	('e85c40e7-6f29-4e22-9787-6ed289c36429', 'Charlesworth Building', NULL, '2025-05-24 12:20:54.129832+00', '2025-06-30 18:02:04.346012+00', 20, true, 'CH'),
	('69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Unit', NULL, '2025-05-24 15:31:30.919629+00', '2025-06-14 09:47:13.889057+00', 0, false, NULL),
	('d4d0bf79-eb71-477e-9d06-03159039e425', 'New Fountain House', NULL, '2025-05-24 12:20:27.560098+00', '2025-06-14 09:47:13.889057+00', 40, false, NULL),
	('e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal Unit', NULL, '2025-05-24 15:34:16.907485+00', '2025-06-14 09:47:13.889057+00', 50, false, NULL),
	('6d6b02c1-69b0-4c81-8df5-516676b1c3f7', 'Etherow', NULL, '2025-06-14 09:37:10.352275+00', '2025-06-14 09:47:13.889057+00', 60, false, NULL),
	('699f7c00-ccb9-4e57-886d-a9d09d246fc4', 'Buckton', NULL, '2025-06-14 09:34:29.16209+00', '2025-06-14 09:47:13.889057+00', 70, false, NULL),
	('20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', NULL, '2025-05-27 15:49:56.650867+00', '2025-06-14 09:47:13.889057+00', 80, false, NULL),
	('f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Werneth House', '200 Science Boulevard', '2025-05-22 10:30:30.870153+00', '2025-06-14 09:47:13.889057+00', 90, false, NULL),
	('23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Portland Building', NULL, '2025-05-24 15:33:42.930237+00', '2025-06-14 09:47:13.889057+00', 100, false, NULL),
	('e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Bereavement Centre', NULL, '2025-05-24 15:12:37.764027+00', '2025-06-14 09:47:13.889057+00', 120, false, NULL),
	('a7b5df98-955c-40eb-873e-324a6a598dc9', 'Gas Stores', NULL, '2025-06-23 15:08:12.180141+00', '2025-06-23 15:08:12.180141+00', 0, false, NULL),
	('abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Main Stores', NULL, '2025-05-29 08:52:06.678532+00', '2025-06-23 15:08:22.916214+00', 110, false, NULL);


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."departments" ("id", "building_id", "name", "is_frequent", "created_at", "updated_at", "sort_order", "color") VALUES
	('f47ac10b-58cc-4372-a567-0e02b2c3d483', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 41', true, '2025-05-22 10:30:30.870153+00', '2025-05-28 12:25:54.280198+00', 10, '#CCCCCC'),
	('2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'NICU', true, '2025-05-24 12:21:01.329031+00', '2025-05-30 10:35:46.86368+00', 0, '#CCCCCC'),
	('6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 27', true, '2025-05-24 15:04:56.615271+00', '2025-05-30 10:35:46.86368+00', 10, '#CCCCCC'),
	('9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 30 (HCU)', true, '2025-05-24 15:05:26.651408+00', '2025-05-30 10:35:46.86368+00', 30, '#CCCCCC'),
	('c24a3784-6a06-469f-a764-49621f2d88d3', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Ward 31', true, '2025-05-24 15:05:37.494475+00', '2025-05-30 10:35:46.86368+00', 40, '#CCCCCC'),
	('831035d1-93e9-4683-af25-b40c2332b2fe', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'EOU', true, '2025-05-22 10:41:18.749919+00', '2025-05-30 10:36:52.347554+00', 50, '#CCCCCC'),
	('a8d3be01-4d46-41c1-b304-ab98610847e7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Vasular Studies', true, '2025-05-24 15:06:04.488647+00', '2025-05-30 10:37:13.256208+00', 160, '#CCCCCC'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d487', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Library', false, '2025-05-22 10:30:30.870153+00', '2025-05-28 09:40:45.973966+00', 30, '#CCCCCC'),
	('9056ee14-242b-4208-a87d-fc59d24d442c', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Pathology Lab', false, '2025-05-24 12:20:41.049859+00', '2025-05-28 09:40:45.973966+00', 70, '#CCCCCC'),
	('fa9e4d42-8282-42f8-bfd4-87691e20c7ed', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Labour Ward', false, '2025-05-24 15:05:14.044021+00', '2025-05-28 09:40:45.973966+00', 110, '#CCCCCC'),
	('6dc82d06-d4d2-4824-9a83-d89b583b7554', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'SDEC', false, '2025-05-24 15:05:53.620867+00', '2025-05-28 09:40:45.973966+00', 150, '#CCCCCC'),
	('42c2b3ab-f68d-429c-9675-3c79ff0ed222', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Ultrasound', false, '2025-05-24 15:07:04.431723+00', '2025-05-28 09:40:45.973966+00', 200, '#CCCCCC'),
	('35c73844-b511-423e-996c-5328ef21fedd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Clinics A-F', false, '2025-05-24 15:07:14.550747+00', '2025-05-28 09:40:45.973966+00', 210, '#CCCCCC'),
	('7295def1-1827-46dc-a443-a7aa7bf85b52', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Yellow Suite', false, '2025-05-24 15:07:27.863388+00', '2025-05-28 09:40:45.973966+00', 220, '#CCCCCC'),
	('f7c99832-60d1-42ee-8d35-0620a38f1e5d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Blue Suite', false, '2025-05-24 15:07:36.0704+00', '2025-05-28 09:40:45.973966+00', 230, '#CCCCCC'),
	('465893b5-6ab8-4776-bdbd-fd3c608ab966', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Swan Room', false, '2025-05-24 15:07:48.317926+00', '2025-05-28 09:40:45.973966+00', 240, '#CCCCCC'),
	('ac2333d2-0b37-4924-a039-478caf702fbd', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s O+A', false, '2025-05-24 15:08:31.112268+00', '2025-05-28 09:40:45.973966+00', 260, '#CCCCCC'),
	('f7525622-cd84-4c8c-94bf-b0428008b9c3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Frailty', false, '2025-05-24 15:10:12.266212+00', '2025-05-28 09:40:45.973966+00', 300, '#CCCCCC'),
	('19b02bca-1dc6-4d00-b04d-a7e141a04870', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Plaster Room', false, '2025-05-24 15:10:32.921441+00', '2025-05-28 09:40:45.973966+00', 320, '#CCCCCC'),
	('76753b4b-ae1e-4477-a042-8deaab558e7b', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Discharge Lounge', false, '2025-05-24 15:11:40.525042+00', '2025-05-28 09:40:45.973966+00', 340, '#CCCCCC'),
	('99d8db21-2c14-4f8f-8e54-54fc81004997', 'e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Rose Cottage', false, '2025-05-24 15:12:49.940045+00', '2025-05-28 09:40:45.973966+00', 390, '#CCCCCC'),
	('87a21a43-fe29-448f-9c08-b4d94226ad3f', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Infection Control', false, '2025-05-24 15:13:12.738948+00', '2025-05-28 09:40:45.973966+00', 400, '#CCCCCC'),
	('60c6f384-09d7-4ec8-bc90-b72fe1d82af9', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Switch', false, '2025-05-24 15:13:28.133871+00', '2025-05-28 09:40:45.973966+00', 410, '#CCCCCC'),
	('c06cd3c4-8993-4e7b-b198-a7fda4ede658', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Estates Management', false, '2025-05-24 15:13:37.481503+00', '2025-05-28 09:40:45.973966+00', 420, '#CCCCCC'),
	('c0a07de6-b201-441b-a1fb-2b2ae9a95ac1', 'f47ac10b-58cc-4372-a567-0e02b2c3d481', 'Reception', false, '2025-05-24 15:16:21.942089+00', '2025-05-28 09:40:45.973966+00', 460, '#CCCCCC'),
	('bcb9ab4c-88c9-4d90-8b10-d97216de49ed', 'd4d0bf79-eb71-477e-9d06-03159039e425', 'Transfusion', false, '2025-05-24 15:20:33.127806+00', '2025-05-28 09:40:45.973966+00', 470, '#CCCCCC'),
	('5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Mattress Store', false, '2025-05-24 15:21:31.144781+00', '2025-05-28 09:40:45.973966+00', 490, '#CCCCCC'),
	('9dae2f86-2058-4c9c-a428-76f5648553d3', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'North Theatres', false, '2025-05-24 15:24:43.214387+00', '2025-05-28 09:40:45.973966+00', 500, '#CCCCCC'),
	('07e2b454-88ee-4d6a-9d75-a6ffa39bd241', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'South Theatres', false, '2025-05-24 15:24:51.854136+00', '2025-05-28 09:40:45.973966+00', 510, '#CCCCCC'),
	('d82e747e-5e94-44cb-9fd6-2ab98f4c3f53', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'MRI', false, '2025-05-24 15:25:16.973586+00', '2025-05-28 09:40:45.973966+00', 530, '#CCCCCC'),
	('df3d8d2a-dee5-4a21-a362-401236a2a1cb', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Pharmacy', false, '2025-05-24 15:30:28.871857+00', '2025-05-28 09:40:45.973966+00', 540, '#CCCCCC'),
	('943915e4-6818-4890-b395-a8272718eaf7', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford One', false, '2025-05-24 15:31:43.707094+00', '2025-05-28 09:40:45.973966+00', 550, '#CCCCCC'),
	('0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Two', false, '2025-05-24 15:31:53.020936+00', '2025-05-28 09:40:45.973966+00', 560, '#CCCCCC'),
	('1cac53b0-f370-4a13-95ca-f4cfd85dd197', '69fc7835-337f-4155-946f-e5831a123cbe', 'Stamford Ground', false, '2025-05-24 15:32:00.795352+00', '2025-05-28 09:40:45.973966+00', 570, '#CCCCCC'),
	('55f54692-d1ee-4047-bace-ff31744d2bc7', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'FM Corridor', false, '2025-05-24 15:32:36.1272+00', '2025-05-28 09:40:45.973966+00', 580, '#CCCCCC'),
	('270df887-a13f-4004-a58d-9cec125b8da1', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Kitchens', false, '2025-05-24 15:32:43.567186+00', '2025-05-28 09:40:45.973966+00', 590, '#CCCCCC'),
	('06582332-0637-4d1a-b86e-876afe0bdc98', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Laundry', false, '2025-05-24 15:33:51.477397+00', '2025-05-28 09:40:45.973966+00', 600, '#CCCCCC'),
	('bf03ffcf-98d7-440e-adc1-5081e161c42d', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'I.T.', false, '2025-05-24 15:33:57.806509+00', '2025-05-28 09:40:45.973966+00', 610, '#CCCCCC'),
	('2368699a-6de0-45a9-ae25-dad26160cada', '23271f2b-4336-4a4a-99a2-49d8d5770cfc', 'Porters Lodge', false, '2025-05-24 15:34:07.683358+00', '2025-05-28 09:40:45.973966+00', 620, '#CCCCCC'),
	('ccb6bf8f-275c-4d24-8907-09b97cbe0eea', 'e02f0b82-4bfc-4579-911a-ec20d4dbbf30', 'Renal', false, '2025-05-24 15:34:28.590837+00', '2025-05-28 09:40:45.973966+00', 630, '#CCCCCC'),
	('4c0821a2-dba8-48fe-9b8d-1c1ed6f8edea', '20fef7b8-5b9d-40ce-927e-029e707cc9d7', 'Walkerwood', false, '2025-05-27 15:50:07.946454+00', '2025-05-28 09:40:45.973966+00', 640, '#CCCCCC'),
	('1ae5c936-b74c-453e-a614-42b983416e40', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 43', true, '2025-05-24 15:11:49.971178+00', '2025-05-28 11:48:51.366161+00', 0, '#CCCCCC'),
	('571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Womens Health', true, '2025-05-24 15:14:53.225063+00', '2025-05-30 10:35:46.86368+00', 20, '#CCCCCC'),
	('dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Children''s Unit', false, '2025-05-24 15:08:15.838239+00', '2025-05-30 10:36:42.972929+00', 0, '#CCCCCC'),
	('8a58923e-5de7-46af-9e38-0cb4f266f728', '6d6b02c1-69b0-4c81-8df5-516676b1c3f7', 'Summers', false, '2025-06-14 09:39:05.997807+00', '2025-06-14 09:39:05.997807+00', 0, '#CCCCCC'),
	('1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'A+E (ED)', false, '2025-05-24 15:06:24.428146+00', '2025-06-05 05:47:42.426275+00', 170, '#29c7b4'),
	('81c30d93-8712-405c-ac5e-509d48fd9af9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'AMU', true, '2025-05-23 14:37:07.660982+00', '2025-06-14 09:44:27.376555+00', 10, '#e1c84c'),
	('f9d3bbce-8644-4075-8b80-457777f6d16c', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Ground Floor', false, '2025-05-24 15:06:39.563069+00', '2025-06-05 06:09:41.18236+00', 180, '#bd2e73'),
	('1831f136-80c5-4b85-9eff-b28610808802', '6d6b02c1-69b0-4c81-8df5-516676b1c3f7', 'Hague Ward', false, '2025-06-14 09:39:43.15457+00', '2025-06-14 09:39:43.15457+00', 0, '#CCCCCC'),
	('8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'XRay Lower Ground Floor', false, '2025-05-24 15:06:52.499906+00', '2025-06-05 06:10:37.909591+00', 190, '#bd2e73'),
	('5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'CT Scan', false, '2025-05-24 15:25:11.218374+00', '2025-06-05 06:11:50.78881+00', 520, '#bd2e73'),
	('a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'CDS (Acorn Birth Centre)', true, '2025-05-24 15:14:21.560252+00', '2025-06-11 13:42:08.798467+00', 430, '#CCCCCC'),
	('7d18efe7-8c7e-4a6d-a77a-ee75c903bc63', '699f7c00-ccb9-4e57-886d-a9d09d246fc4', 'Tatton', false, '2025-06-14 09:35:21.939345+00', '2025-06-14 09:35:21.939345+00', 0, '#CCCCCC'),
	('74c28939-9217-4340-88dd-ba5667fd1b5a', '6d6b02c1-69b0-4c81-8df5-516676b1c3f7', 'Saxon', false, '2025-06-14 09:37:31.134183+00', '2025-06-14 09:37:31.134183+00', 0, '#CCCCCC'),
	('7babbb12-15f9-4483-8b05-61220ed37167', '699f7c00-ccb9-4e57-886d-a9d09d246fc4', 'Taylor Ward', false, '2025-06-14 09:37:53.291483+00', '2025-06-14 09:37:53.291483+00', 0, '#CCCCCC'),
	('969a27a7-f5e5-4c23-b018-128aa2000b97', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Bed Store', false, '2025-05-24 15:21:21.166917+00', '2025-06-14 09:44:23.642271+00', 480, '#CCCCCC'),
	('7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Day Surgery', true, '2025-05-24 15:09:06.573728+00', '2025-06-14 09:44:37.821324+00', 270, '#CCCCCC'),
	('4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Endoscopy Unit', true, '2025-05-24 15:09:18.185641+00', '2025-06-14 09:44:46.750486+00', 280, '#CCCCCC'),
	('8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'IAU', true, '2025-05-24 15:05:46.603744+00', '2025-06-14 09:44:49.723927+00', 140, '#CCCCCC'),
	('36e599c5-89b2-4d50-b7df-47d5d1959ca4', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Surgical Hub', true, '2025-05-24 15:10:26.062318+00', '2025-06-14 09:44:54.916221+00', 310, '#CCCCCC'),
	('0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 44', true, '2025-05-24 15:11:55.713923+00', '2025-06-14 09:45:26.977013+00', 360, '#CCCCCC'),
	('3aa17398-7823-45ae-b76c-9b30d8509ce1', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 42', true, '2025-05-24 15:11:16.394196+00', '2025-06-14 09:45:31.764096+00', 10, '#CCCCCC'),
	('f47ac10b-58cc-4372-a567-0e02b2c3d484', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 40', true, '2025-05-22 10:30:30.870153+00', '2025-06-14 09:45:33.367114+00', 20, '#CCCCCC'),
	('569e9211-d394-4e93-ba3e-34ad20d98af4', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 45', true, '2025-05-24 15:12:01.01766+00', '2025-06-14 09:45:36.01997+00', 370, '#CCCCCC'),
	('0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'f47ac10b-58cc-4372-a567-0e02b2c3d479', 'Ward 46', true, '2025-05-24 15:12:07.981632+00', '2025-06-14 09:45:37.070722+00', 380, '#CCCCCC'),
	('c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'POU', true, '2025-05-24 15:09:37.760662+00', '2025-06-14 09:46:42.323777+00', 290, '#CCCCCC'),
	('02c59898-fa58-4b51-b446-7f68dfa1bb9e', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Critical Care (ITU)', false, '2025-06-15 09:59:26.314764+00', '2025-06-15 09:59:26.314764+00', 0, '#CCCCCC'),
	('44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'ISGU', true, '2025-06-15 09:58:51.099504+00', '2025-06-15 09:59:33.298695+00', 0, '#CCCCCC'),
	('23199491-fe75-4c33-9cc8-1c86070cf0d1', 'e85c40e7-6f29-4e22-9787-6ed289c36429', 'Maternity Triage', false, '2025-05-24 15:15:20.429518+00', '2025-06-15 10:48:54.902649+00', 450, '#CCCCCC'),
	('167c7358-aa39-498e-b0b0-bda652b27401', 'e5f1f6d5-d277-4981-bffa-ff8d8b8c8eef', 'Mortuary', false, '2025-06-15 14:27:06.102815+00', '2025-06-15 14:27:06.102815+00', 0, '#CCCCCC'),
	('a189c856-581e-4d86-9dc2-de6995be4a3a', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'ACU', false, '2025-06-15 16:14:56.75423+00', '2025-06-15 16:14:56.75423+00', 0, '#CCCCCC'),
	('7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Bed store', false, '2025-06-17 19:19:40.378598+00', '2025-06-17 19:19:40.378598+00', 0, '#CCCCCC'),
	('4430a59f-4d77-4b74-9a3c-3f2430620842', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Mattress Store', false, '2025-06-17 19:19:53.546917+00', '2025-06-17 19:19:53.546917+00', 0, '#CCCCCC'),
	('d213240b-3564-467a-9c2e-465bf4affe6a', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Gas Store', false, '2025-06-17 19:20:07.969417+00', '2025-06-17 19:20:07.969417+00', 0, '#CCCCCC'),
	('06b9e480-8192-4637-be08-07e1755dbd6f', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Bin Store', false, '2025-06-17 19:24:16.498895+00', '2025-06-17 19:24:16.498895+00', 0, '#CCCCCC'),
	('2aaff65e-ca83-42ce-961f-802b7a0137ab', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'Corridor / Other Dept.', false, '2025-06-17 19:25:32.006656+00', '2025-06-17 19:26:37.504336+00', 0, '#CCCCCC'),
	('3a99e4e7-8e55-4362-b4c8-8a051620d478', 'b4891ac9-bb9c-4c63-977d-038890607b98', 'Urology', false, '2025-06-18 15:24:36.472606+00', '2025-06-18 15:24:36.472606+00', 0, '#CCCCCC'),
	('90aad46b-f52f-4c04-9e84-f38d82ba7387', 'abcc57d8-0d21-47ae-83ba-cb6da7f80425', 'General Stores', false, '2025-06-25 20:21:26.080682+00', '2025-06-25 20:21:26.080682+00', 0, '#CCCCCC');


--
-- Data for Name: default_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_assignments" ("id", "department_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('739eaa0c-5cd3-4c1d-9e10-594d14531c2e', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_night', '20:00:00', '08:00:00', '#4285F4', '2025-06-24 22:16:56.874877+00', '2025-06-24 22:16:56.874877+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('30f9760e-1d57-47eb-b74b-e80678cae7b9', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_night', '20:00:00', '08:00:00', '#4285F4', '2025-06-24 22:17:48.237413+00', '2025-06-24 22:17:48.237413+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('01c26e7c-06e6-46ca-9c16-7bf624cbb5c9', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:46:07.775253+00', '2025-06-30 15:46:07.775253+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8ae8fc5d-adca-4b8b-9396-cfe343f4683d', 'f9d3bbce-8644-4075-8b80-457777f6d16c', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:45:25.290845+00', '2025-06-30 15:48:45.114511+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('3ef8bd12-d8e0-4b4e-ac75-360bbed02cdd', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:45:39.290922+00', '2025-06-30 15:51:50.002263+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('9596dd7a-7b63-425d-930b-cec31bc462bf', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:45:48.314641+00', '2025-06-30 15:53:02.623991+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fe2dc547-ae2b-4b5b-916a-5e13cb6c30fb', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-06-24 17:33:11.748042+00', '2025-06-30 16:46:46.33086+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."staff" ("id", "first_name", "last_name", "role", "created_at", "updated_at", "department_id", "porter_type", "availability_pattern", "contracted_hours_start", "contracted_hours_end") VALUES
	('6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', 'KG', 'Porter', 'porter', '2025-05-28 15:38:38.608871+00', '2025-05-30 16:20:37.92001+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('e9cf3a23-c94a-409b-aa71-d42602e54068', 'MP', 'Porter', 'porter', '2025-05-28 15:38:29.329131+00', '2025-05-30 16:21:01.802578+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('f304fa99-8e00-48d0-a616-d156b0f7484d', 'CW', 'Porter', 'porter', '2025-05-24 15:29:00.080381+00', '2025-05-30 17:10:15.855945+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('4fb21c6f-2f5b-4f6e-b727-239a3391092a', 'EA', 'Porter', 'porter', '2025-05-24 15:29:10.541023+00', '2025-05-30 17:10:43.050862+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('394d8660-7946-4b31-87c9-b60f7e1bc294', 'GB', 'Porter', 'porter', '2025-05-23 14:36:44.275665+00', '2025-05-30 17:11:04.72929+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('050fa6e6-477b-4f83-aae4-3e13c954ca6a', 'Xray', 'Porter 1', 'porter', '2025-05-28 15:40:45.206052+00', '2025-05-28 15:40:45.206052+00', NULL, 'shift', NULL, NULL, NULL),
	('cb50a5b2-3812-4688-b1f6-ccf0ab7626b6', 'Xray', 'Porter 2', 'porter', '2025-05-28 15:40:56.522945+00', '2025-05-28 15:40:56.522945+00', NULL, 'shift', NULL, NULL, NULL),
	('473eeca1-e8ca-49a7-b2f6-5870dc254dcc', 'No', 'Supervisor', 'supervisor', '2025-05-29 12:56:45.696149+00', '2025-05-29 12:56:45.696149+00', NULL, 'shift', NULL, NULL, NULL),
	('80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', 'RS', 'Porter', 'porter', '2025-05-28 15:38:06.309697+00', '2025-05-30 16:21:29.758058+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('c3052ff8-8339-4e02-b4ed-efee9365e7c2', 'MC', 'Porter', 'porter', '2025-05-28 15:37:56.707711+00', '2025-05-30 16:21:53.673996+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('8b3b3e97-ea54-4c40-884b-04d3d24dbe23', 'JM', 'Porter', 'porter', '2025-05-24 15:46:43.723804+00', '2025-05-30 17:13:40.748857+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('e55b1013-7e79-4e38-913e-c53de591f85c', 'LR', 'Porter', 'porter', '2025-05-24 15:47:03.70938+00', '2025-05-30 17:13:59.97549+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('69766d05-49d7-4e7c-8734-e3dc8949bf91', 'MD', 'Porter', 'porter', '2025-05-24 15:47:22.720752+00', '2025-05-30 17:15:12.217517+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('75ff4301-3c45-44c5-bd93-1b3a471baaeb', 'IS', 'Porter', 'porter', '2025-05-22 15:14:47.797324+00', '2025-05-30 17:15:38.338145+00', NULL, 'shift', 'Weekdays - Days', '07:30:00', '15:30:00'),
	('1a21db6c-9a35-48ca-a3b0-06284bec8beb', 'AJ', 'Porter', 'porter', '2025-05-28 15:39:12.414354+00', '2025-05-30 16:22:30.530571+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('04947318-f8a7-4eea-8044-5219c5e907fc', 'CB', 'Porter', 'porter', '2025-05-28 15:36:24.156976+00', '2025-05-31 09:20:58.647194+00', NULL, 'shift', 'Weekends - Days', '11:00:00', '19:00:00'),
	('ecc67de0-fecc-4c93-b9da-445c3cef4ea4', 'LY', 'Porter', 'porter', '2025-05-24 15:28:41.635621+00', '2025-05-31 12:05:19.000564+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', 'DM', 'Porter 1', 'porter', '2025-05-28 15:40:00.100404+00', '2025-05-30 16:19:39.09899+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('2ef290c6-6c61-4d37-be45-d08ae6afc097', 'DM', 'Porter 2', 'porter', '2025-05-28 15:40:14.777056+00', '2025-05-30 16:20:03.887273+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('83fdb588-e638-47ae-b726-51f83a4378c7', 'MS', 'Porter', 'porter', '2025-05-28 15:39:06.096334+00', '2025-05-30 16:23:02.826204+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('56d5a952-a958-41c5-aa28-bd42e06720c8', 'MH', 'Porter', 'porter', '2025-05-28 15:37:14.70567+00', '2025-05-30 16:24:43.554717+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('b96a6ffa-6f54-4eab-a1c8-5c65dc7223da', 'MW', 'Porter', 'porter', '2025-05-28 15:37:22.975093+00', '2025-05-30 16:25:18.624641+00', NULL, 'shift', 'Weekdays - Days', '06:00:00', '14:00:00'),
	('296edb55-91eb-4d73-aa43-54840cbbf20c', 'AB', 'Porter', 'porter', '2025-05-28 15:37:34.781762+00', '2025-05-30 16:25:58.74326+00', NULL, 'shift', 'Weekdays - Days', '14:00:00', '22:00:00'),
	('8eaa9194-b164-4cb4-a15c-956299ff28c5', 'TB', 'Porter', 'porter', '2025-05-24 15:46:56.110419+00', '2025-05-30 16:28:35.874646+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('ad9b079b-07fc-4ece-99b1-a33b0b8a97bc', 'MH', 'Porter 2', 'porter', '2025-05-22 15:14:27.136064+00', '2025-05-30 16:29:52.389588+00', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('2e74429e-2aab-4bed-a979-6ccbdef74596', 'JR', 'Porter', 'porter', '2025-05-24 15:27:50.974195+00', '2025-05-30 16:30:18.953012+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', 'LS', 'Porter', 'porter', '2025-05-24 15:28:02.842334+00', '2025-05-30 16:59:08.457239+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('bf79faf6-fb3e-4780-841e-63a4a67a5b77', 'NB', 'Porter', 'porter', '2025-05-24 15:28:15.192437+00', '2025-05-30 17:08:00.606828+00', NULL, 'shift', 'Weekdays - Days', '13:00:00', '23:00:00'),
	('7c20aec3-bf78-4ef9-b35e-429e41ac739b', 'KS', 'Porter', 'porter', '2025-05-24 15:28:35.013201+00', '2025-05-30 17:09:23.036433+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('2524b1c5-45e1-4f15-bf3b-984354f22cdc', 'PM', 'Porter', 'porter', '2025-05-24 15:28:50.433536+00', '2025-05-30 17:09:45.582369+00', NULL, 'shift', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('172b28c4-ec0d-4f5c-a859-ff8299ff6243', 'SS', 'Porter', 'porter', '2025-05-31 09:23:33.02904+00', '2025-05-31 09:23:33.02904+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('b4bcc3bc-729a-49fe-bf6e-1c30fcac37b3', 'JF', 'Porter', 'porter', '2025-05-31 09:24:06.944074+00', '2025-05-31 09:24:06.944074+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('00e0ca67-f415-45ce-9b11-c3260e9cd58e', 'SB', 'Porter', 'porter', '2025-05-31 09:24:52.480925+00', '2025-05-31 09:24:52.480925+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('d34fa6f7-8d2d-4e20-abda-a77c11554254', 'DF', 'Porter', 'porter', '2025-05-31 09:31:17.530822+00', '2025-05-31 09:31:17.530822+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
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
	('a9d969e3-d449-4005-a679-f63be07c6872', 'LC', 'Supervisor', 'supervisor', '2025-05-22 16:39:16.282662+00', '2025-06-12 11:37:04.326153+00', NULL, 'shift', NULL, NULL, NULL),
	('4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'MS', 'Supervisor', 'supervisor', '2025-05-22 16:38:43.142566+00', '2025-06-12 11:37:11.473401+00', NULL, 'shift', NULL, NULL, NULL),
	('786d6d23-69b9-433e-92ed-938806cb10a8', 'LB', 'Porter', 'porter', '2025-05-23 14:15:42.030594+00', '2025-06-18 12:03:45.75891+00', NULL, 'relief', '4 on 4 off - Days', '14:00:00', '22:00:00'),
	('12055968-78d3-4404-a05f-10e039217936', 'MB', 'Porter', 'porter', '2025-05-24 15:35:19.897285+00', '2025-06-18 14:29:31.367687+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('1aaab277-ecf2-40dd-a764-eaaf8af7615b', 'AT', 'Porter', 'porter', '2025-05-28 15:36:02.205704+00', '2025-06-23 15:10:31.919484+00', NULL, 'shift', '4 on 4 off - Days', '10:00:00', '22:00:00'),
	('5bfb19a8-f295-4e17-b63d-01166fd22acf', 'BC', 'Porter (N)', 'porter', '2025-05-31 09:31:35.719888+00', '2025-06-25 18:09:04.429393+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('4b49d53b-2473-4cc9-9b08-221a6548a93d', 'JM', 'Porter (N)', 'porter', '2025-05-31 09:31:58.967695+00', '2025-06-25 18:08:07.953416+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'JR', 'Porter (N)', 'porter', '2025-05-24 15:28:21.287841+00', '2025-06-25 18:08:40.678443+00', NULL, 'shift', 'Weekdays - Nights', '20:00:00', '08:00:00'),
	('af42f57f-1437-4320-b1a2-2b0051948de3', 'AK', 'Porter ((N)', 'porter', '2025-05-31 09:32:32.204314+00', '2025-06-25 18:14:16.357298+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('7cc268aa-cb72-4320-ba8d-72f77b77dda6', 'DP', 'Porter', 'porter', '2025-05-31 09:36:39.240883+00', '2025-06-30 15:50:24.725379+00', NULL, 'shift', 'Weekdays - Days', '10:00:00', '18:00:00'),
	('4377dd38-cf15-4de2-8347-0461ba6afff5', 'SH', 'Porter', 'porter', '2025-05-28 15:36:45.727912+00', '2025-06-30 15:54:21.529927+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', 'SM', 'Porter', 'porter', '2025-05-28 15:36:52.317877+00', '2025-06-30 15:54:31.419126+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('c162858c-9815-43e3-9bcb-0c709bd8eef0', 'SC', 'Porter', 'porter', '2025-05-28 15:39:52.203155+00', '2025-06-30 16:00:49.283201+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('4e87f01b-5196-47c4-b424-4cfdbe7fb385', 'SC', 'Porter (2)', 'porter', '2025-05-24 15:47:12.658077+00', '2025-06-30 16:01:01.178781+00', NULL, 'relief', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('63f5c89b-661d-40e5-a810-7fba772d4dc5', 'KB', 'Porter', 'porter', '2025-05-31 09:30:45.461948+00', '2025-06-30 16:02:54.07368+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('c3579d99-b97e-4019-b37a-f63515fe3ca4', 'PB', 'Porter', 'porter', '2025-05-31 11:52:53.118104+00', '2025-05-31 11:52:53.118104+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', 'RF', 'Porter', 'porter', '2025-05-31 11:53:07.6934+00', '2025-05-31 11:53:07.6934+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('ac5427be-ea01-4f42-9c46-17e2f089dee8', 'AG', 'Porter', 'porter', '2025-05-31 11:53:20.904075+00', '2025-05-31 11:53:20.904075+00', NULL, 'shift', 'Weekdays - Days', '09:00:00', '17:00:00'),
	('7a905342-f7d6-4105-b56f-d922e86dbbd9', 'NB', 'Porter', 'porter', '2025-05-31 11:53:50.689917+00', '2025-05-31 11:53:50.689917+00', NULL, 'shift', 'Weekdays - Days', '08:30:00', '16:30:00'),
	('2fe13155-0425-4634-b42a-04380ff73ad1', 'PF', 'Porter', 'porter', '2025-05-31 11:54:42.540751+00', '2025-05-31 11:54:42.540751+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('ccac560c-a3ad-4517-895d-86870e9ad00a', 'AF', 'Porter', 'porter', '2025-05-31 12:05:54.898527+00', '2025-05-31 12:05:54.898527+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('6e772f6a-e4e8-422a-b21b-ff677b625471', 'SO', 'Porter', 'porter', '2025-05-31 12:07:12.641402+00', '2025-05-31 12:07:12.641402+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '16:00:00'),
	('a55d23b5-154f-425b-a0b3-11d5e3ef5ffd', 'MR', 'Porter', 'porter', '2025-05-31 12:09:18.007059+00', '2025-05-31 12:09:18.007059+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('b30280c2-aecc-4953-a1df-5f703bce4772', 'JN', 'Porter', 'porter', '2025-06-02 17:25:09.547001+00', '2025-06-02 17:25:09.547001+00', NULL, 'shift', 'Weekdays - Days', '07:00:00', '15:00:00'),
	('85d80fef-9a4b-4878-b647-63301e934b51', 'PH', 'Porter 2', 'porter', '2025-06-05 06:28:40.304454+00', '2025-06-05 06:31:09.403628+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('358aa759-e11e-40b0-b886-37481c5eb6c0', 'CC', 'Supervisor', 'supervisor', '2025-05-22 16:39:03.319212+00', '2025-06-12 11:36:56.747139+00', NULL, 'shift', NULL, NULL, NULL),
	('b88b49d1-c394-491e-aaa7-cc196250f0e4', 'MF', 'Supervisor', 'supervisor', '2025-05-22 12:36:39.488519+00', '2025-06-12 11:37:21.803006+00', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'shift', NULL, NULL, NULL),
	('0c601480-b2ff-4199-9b59-5d437ee3c238', 'SF', 'Porter', 'porter', '2025-06-15 07:44:08.369566+00', '2025-06-15 07:44:08.369566+00', NULL, 'shift', '4 on 4 off - Days', '06:00:00', '14:00:00'),
	('2840c515-644f-4313-9c30-ecfe7dd1cbe8', 'RM', 'Porter', 'porter', '2025-06-15 13:10:13.750468+00', '2025-06-15 13:10:13.750468+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('aee3e923-d013-4da1-8404-6dfe4f07c135', 'JE', 'Porter', 'porter', '2025-06-15 13:10:32.472095+00', '2025-06-15 13:10:32.472095+00', NULL, 'shift', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('a33f17c7-38b0-4a1d-86f0-b7957ec5b970', 'KT', 'Porter', 'porter', '2025-06-16 16:23:15.772625+00', '2025-06-16 16:23:15.772625+00', NULL, 'shift', '4 on 4 off - Days', '10:00:00', '10:00:00'),
	('1f1e61c3-848c-441c-8b89-8a85e16285df', 'DS', 'Porter (N)', 'porter', '2025-05-31 12:09:48.190182+00', '2025-06-25 18:59:25.177543+00', NULL, 'shift', '4 on 4 off - Nights', '20:00:00', '08:00:00'),
	('fabfccff-9e98-4965-83c2-97f388a7672e', 'MH', 'Porter (R)', 'porter', '2025-06-30 15:55:55.019092+00', '2025-06-30 15:55:55.019092+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '20:00:00'),
	('c965e4e3-e132-43f0-94ce-1b41d33a9f05', 'CR', 'Porter', 'porter', '2025-05-28 15:36:13.899635+00', '2025-06-30 15:56:08.06632+00', NULL, 'relief', '4 on 4 off - Days', '08:00:00', '20:00:00'),
	('920b6b2f-18f0-4f27-b3b8-3b5760f6afc8', 'JB', 'Porter', 'porter', '2025-06-25 18:25:55.70792+00', '2025-06-30 15:56:34.266464+00', NULL, 'relief', 'Weekdays - Days', '06:00:00', '14:00:00'),
	('4e543605-21a0-4373-8434-7f9809abea33', 'GW', 'Porter', 'porter', '2025-06-30 15:57:01.504945+00', '2025-06-30 15:57:01.504945+00', NULL, 'relief', 'Weekdays - Days', '08:00:00', '20:00:00');


--
-- Data for Name: default_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_area_cover_porter_assignments" ("id", "default_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('6ccd317c-236d-44ad-8f67-327317699166', '8ae8fc5d-adca-4b8b-9396-cfe343f4683d', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-30 15:48:45.206446+00', '2025-06-30 15:48:45.206446+00'),
	('518e3800-7ebf-4f13-965b-b3bd2ba0c496', '8ae8fc5d-adca-4b8b-9396-cfe343f4683d', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-30 15:48:45.269126+00', '2025-06-30 15:48:45.269126+00'),
	('acd10993-ae5a-40a8-9612-35efc7f4690d', '3ef8bd12-d8e0-4b4e-ac75-360bbed02cdd', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-30 15:51:50.059404+00', '2025-06-30 15:51:50.059404+00'),
	('7808a6a6-ba01-49fd-940b-bba16e6db870', '3ef8bd12-d8e0-4b4e-ac75-360bbed02cdd', '7cc268aa-cb72-4320-ba8d-72f77b77dda6', '10:00:00', '18:00:00', '2025-06-30 15:51:50.129605+00', '2025-06-30 15:51:50.129605+00'),
	('1e41a0df-6b74-4b48-bfd7-f6ad8347f00d', '9596dd7a-7b63-425d-930b-cec31bc462bf', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-30 15:53:02.685219+00', '2025-06-30 15:53:02.685219+00'),
	('23d709d7-4d6a-4293-b316-e05bd4c11158', '9596dd7a-7b63-425d-930b-cec31bc462bf', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-30 15:53:02.747802+00', '2025-06-30 15:53:02.747802+00'),
	('4608063f-e694-48af-904a-cf618354d6c8', 'fe2dc547-ae2b-4b5b-916a-5e13cb6c30fb', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-24 17:33:46.592422+00', '2025-06-30 16:46:46.427797+00'),
	('d9281b8a-71cb-4df0-9117-1d4f28adf8cc', 'fe2dc547-ae2b-4b5b-916a-5e13cb6c30fb', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '13:00:00', '23:00:00', '2025-06-24 17:35:27.211687+00', '2025-06-30 16:46:46.512102+00'),
	('40f56e6d-75ef-42d8-9c19-147cc5517b40', 'fe2dc547-ae2b-4b5b-916a-5e13cb6c30fb', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '09:00:00', '17:00:00', '2025-06-24 17:40:28.728945+00', '2025-06-30 16:46:46.605425+00'),
	('3be9f7c9-76b9-4617-a531-08b432c18ece', 'fe2dc547-ae2b-4b5b-916a-5e13cb6c30fb', '0c601480-b2ff-4199-9b59-5d437ee3c238', '06:00:00', '14:00:00', '2025-06-30 16:46:46.667385+00', '2025-06-30 16:46:46.667385+00');


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
	('2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'External Waste', NULL, true, '2025-05-28 15:08:35.337525+00', '2025-05-28 15:08:35.337525+00'),
	('976ec471-fd8c-450e-a2ce-5b51993e502c', 'PTS', NULL, true, '2025-06-15 07:47:36.619558+00', '2025-06-15 07:47:36.619558+00'),
	('5c0d3048-e3c9-4efb-a772-1ebf1253e72a', 'Meal Delivery', NULL, true, '2025-06-16 16:27:52.392046+00', '2025-06-16 16:27:52.392046+00');


--
-- Data for Name: default_service_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_assignments" ("id", "service_id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('ce4b641d-619d-4c1b-8c68-d9d850306492', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-28 15:14:07.575453+00', '2025-06-01 11:12:01.865822+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', 'week_day', '07:00:00', '15:00:00', '#c8a76f', '2025-05-28 15:08:50.364355+00', '2025-06-02 17:19:07.627643+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', 'week_day', '08:30:00', '17:00:00', '#4285F4', '2025-05-28 15:07:57.826093+00', '2025-06-04 11:44:12.610082+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('557671ae-71a7-41f5-bbf7-7d74413e7c9a', '0b5c7062-1285-4427-8387-b1b4e14eedc9', 'week_day', '15:00:00', '20:00:00', '#4285F4', '2025-05-28 15:07:40.45798+00', '2025-06-05 04:48:38.545355+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', 'ce940139-6ae7-49de-a62a-0d6ba9397928', 'week_day', '09:00:00', '17:00:00', '#4285F4', '2025-05-28 15:07:33.377391+00', '2025-06-05 04:52:11.826499+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '26c0891b-56c0-4346-8d53-de906aaa64c2', 'week_day', '08:00:00', '16:00:00', '#4285F4', '2025-05-28 15:07:46.235606+00', '2025-06-05 04:54:54.45835+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '7cfa1ddf-61b0-489e-ad23-b924cf995419', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:07:52.088351+00', '2025-06-05 04:55:58.87026+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('aa1a61d1-e538-415a-a89d-9f568fc92adb', '30c5c045-a442-4ec8-b285-c7bc010f4d83', 'week_day', '07:00:00', '15:00:00', '#4285F4', '2025-05-28 15:05:23.573715+00', '2025-06-05 06:38:35.151511+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('f78cc3b7-114b-466b-a293-359d6246b921', '976ec471-fd8c-450e-a2ce-5b51993e502c', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-06-15 07:47:59.422078+00', '2025-06-15 07:47:59.422078+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a09a1bc3-63e4-48e0-a344-f9dbc42c4431', '976ec471-fd8c-450e-a2ce-5b51993e502c', 'week_night', '20:00:00', '01:00:00', '#4285F4', '2025-06-23 15:41:47.711329+00', '2025-06-23 15:41:47.711329+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7fc336ff-13ad-4b4f-9a32-3cde7b7628b4', '976ec471-fd8c-450e-a2ce-5b51993e502c', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-06-24 15:43:55.248957+00', '2025-06-24 15:43:55.248957+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: default_service_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."default_service_cover_porter_assignments" ("id", "default_service_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at") VALUES
	('a8f08037-c45c-4692-bc79-171d7182f8f7', '57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-02 17:19:07.709693+00', '2025-06-02 17:19:07.709693+00'),
	('f3fe847c-e319-4ea8-a4b1-ea0dae937da0', '57f4a7d1-a30b-41e4-86cd-5e5a242f0b3c', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-02 17:19:07.771004+00', '2025-06-02 17:19:07.771004+00'),
	('8317bd19-3ac9-4b0e-a200-7f8d201fa630', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-01 18:54:01.502989+00', '2025-06-04 11:44:12.678498+00'),
	('6dc87b69-0871-447f-a0c0-75cac448c449', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-01 18:54:01.54246+00', '2025-06-04 11:44:12.74195+00'),
	('0c25f6c0-19f1-4288-97cf-9b28212a9e0a', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-01 18:54:01.589009+00', '2025-06-04 11:44:12.814671+00'),
	('4578c334-21c4-4427-9569-cd251016820e', '062b8cbc-3a72-48d1-ba7e-49b2818a909e', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-01 18:54:01.632847+00', '2025-06-04 11:44:12.882056+00'),
	('7e00cfbe-d3b6-412e-b728-504a3256d0b6', '557671ae-71a7-41f5-bbf7-7d74413e7c9a', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-05 04:48:38.636972+00', '2025-06-05 04:48:38.636972+00'),
	('97e2b825-a753-49e5-add4-d506434080bc', '6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-05 04:51:12.878995+00', '2025-06-05 04:52:11.910335+00'),
	('b3caa690-521b-45ed-8ee4-2813865629a3', '6d77ea27-4b2d-4ec6-ba65-7e1d320e0aef', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-05 04:52:11.962278+00', '2025-06-05 04:52:11.962278+00'),
	('d978a8f5-de5c-4e44-b4ef-a249928c490b', '55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-05 04:53:42.467874+00', '2025-06-05 04:54:54.506555+00'),
	('9ad8f215-ae55-4cd6-a029-7da1809341bc', '55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-05 04:54:25.507056+00', '2025-06-05 04:54:54.573688+00'),
	('ae63ea97-d6dd-4acc-8aaf-d41dd798caca', '55c89184-c8b6-4d73-b2dc-d3eed0a06a2f', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-05 04:54:54.615355+00', '2025-06-05 04:54:54.615355+00'),
	('44d34895-d3e5-4a87-b845-67f8aff12f37', '8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-02 17:22:13.804891+00', '2025-06-05 04:55:58.964112+00'),
	('d8f9e89a-3736-4aec-a698-f7a19218362a', '8c3a75ea-dbec-40cc-9d88-ba7da0e0c402', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-05 04:55:59.028775+00', '2025-06-05 04:55:59.028775+00'),
	('bcd0f2a0-34ac-43f6-a860-3224f40d60ee', 'aa1a61d1-e538-415a-a89d-9f568fc92adb', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-05 06:38:35.255003+00', '2025-06-05 06:38:35.255003+00'),
	('8b0fad05-a563-4a4d-ad55-29523c97ac1f', 'aa1a61d1-e538-415a-a89d-9f568fc92adb', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-05 06:38:35.331861+00', '2025-06-05 06:38:35.331861+00');


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
	('e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Asset Removal', NULL, '2025-05-24 15:26:50.239275+00', '2025-05-24 15:26:50.239275+00'),
	('863c44be-48bc-4c08-bec7-603761f90ac2', 'Laundry Items', NULL, '2025-06-15 11:46:52.339806+00', '2025-06-15 11:46:52.339806+00'),
	('a47856e2-f979-4dae-9444-472e548d4a96', 'Coroners', NULL, '2025-06-15 14:20:13.664549+00', '2025-06-15 14:20:13.664549+00'),
	('4792aa3a-96b6-4296-996e-44c1faf79d68', 'Adhoc', NULL, '2025-06-18 16:08:14.926077+00', '2025-06-18 16:08:14.926077+00');


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
	('68e8e006-79dc-4d5f-aed0-20755d53403b', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Wheelchair', NULL, '2025-05-22 11:12:54.89695+00', '2025-05-24 15:18:56.015534+00', false),
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
	('5ae78c1b-b8a8-4938-8ce2-09ed475a1fed', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Oxygen E Size', NULL, '2025-05-24 15:18:10.625096+00', '2025-05-29 17:55:20.230293+00', true),
	('dfe98d58-f606-46f0-afb9-363dfe9a4d3a', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'Blood Sample', NULL, '2025-05-22 11:12:54.89695+00', '2025-06-05 06:40:27.068944+00', true),
	('5c269ddd-7abd-4d10-a0b3-d93fccb4f6de', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Trolly', NULL, '2025-05-24 15:19:02.302787+00', '2025-06-11 16:30:55.48086+00', false),
	('14446938-25cd-4655-ad84-dbb7db871f28', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'Bed', NULL, '2025-05-22 11:12:54.89695+00', '2025-06-11 16:30:55.5597+00', true),
	('1f30972f-7089-432c-953d-24d9ede86e5e', 'b864ed57-5547-404e-9459-1641a030974e', 'Red Bin', NULL, '2025-06-12 13:22:03.774445+00', '2025-06-12 13:22:03.774445+00', false),
	('11069e19-5364-4ec9-b2d4-494c05be7005', 'b864ed57-5547-404e-9459-1641a030974e', 'Resus Box', NULL, '2025-06-12 13:22:14.933584+00', '2025-06-12 13:22:14.933584+00', false),
	('e20813d6-ef72-49bf-807e-20e8c0f2beed', 'b864ed57-5547-404e-9459-1641a030974e', 'Swan Bed', NULL, '2025-06-12 13:22:49.068018+00', '2025-06-12 13:22:49.068018+00', false),
	('cda51b73-2107-4dd3-a61e-29cdc9d7ea4e', 'e89d20b1-1edc-4689-aaf5-ea809fdc9569', 'Resus Box', NULL, '2025-06-12 13:23:36.18411+00', '2025-06-12 13:23:36.18411+00', false),
	('496c3b93-bc9c-4ea3-b022-aa2843d166e0', 'a97d8a74-0e16-4e1f-908e-96e935d91002', 'Entenox Change', NULL, '2025-06-15 10:11:03.450322+00', '2025-06-15 10:11:03.450322+00', false),
	('0d249150-1b05-431d-a918-926b48a804f4', 'b864ed57-5547-404e-9459-1641a030974e', 'Wheelchair', NULL, '2025-06-15 11:31:03.99601+00', '2025-06-15 11:31:03.99601+00', false),
	('b9e98825-d96d-45f3-a865-3ef57f26f9ae', '863c44be-48bc-4c08-bec7-603761f90ac2', 'Pillow Cases', NULL, '2025-06-15 11:47:03.750712+00', '2025-06-15 11:47:03.750712+00', false),
	('88875323-d902-4d5a-b0a6-1609cc42050e', '863c44be-48bc-4c08-bec7-603761f90ac2', 'Sheets', NULL, '2025-06-15 11:47:07.855404+00', '2025-06-15 11:47:07.855404+00', false),
	('7791f4c0-b86e-46bc-be9c-00f9a91325ef', '863c44be-48bc-4c08-bec7-603761f90ac2', 'Pyjamas', NULL, '2025-06-15 11:47:26.18355+00', '2025-06-15 11:47:26.18355+00', false),
	('954aaa9a-d0bc-4d1a-a9f0-288affcc7da8', '863c44be-48bc-4c08-bec7-603761f90ac2', 'Gowns', NULL, '2025-06-15 11:47:35.501181+00', '2025-06-15 11:47:35.501181+00', false),
	('cb673fa9-c4cd-47c0-8526-65e3f10276f0', '863c44be-48bc-4c08-bec7-603761f90ac2', 'Towels', NULL, '2025-06-15 11:47:41.309426+00', '2025-06-15 11:47:41.309426+00', false),
	('c4345550-220c-469c-b413-25a1ba5c433e', '863c44be-48bc-4c08-bec7-603761f90ac2', 'Blankets', NULL, '2025-06-15 11:47:46.684083+00', '2025-06-15 11:47:46.684083+00', false),
	('51b31b47-4164-434f-bc8b-739e65532b43', '863c44be-48bc-4c08-bec7-603761f90ac2', 'Mixed Items', NULL, '2025-06-15 11:49:01.115782+00', '2025-06-15 11:49:01.115782+00', false),
	('a59c446d-7263-4733-93ce-5823448a5fde', 'a47856e2-f979-4dae-9444-472e548d4a96', 'Meet Coroners', NULL, '2025-06-15 14:20:33.175011+00', '2025-06-15 14:20:33.175011+00', false),
	('1e2a9593-d001-4da8-b020-0081d0492468', 'b864ed57-5547-404e-9459-1641a030974e', 'Notes / Paperwork', NULL, '2025-06-12 13:23:19.914641+00', '2025-06-18 15:29:28.405668+00', false),
	('a183cb03-10ec-4dff-8f0d-fafbd4e98ee1', '4792aa3a-96b6-4296-996e-44c1faf79d68', 'Snack Box', NULL, '2025-06-18 16:08:28.688587+00', '2025-06-18 16:08:28.688587+00', false),
	('75d9a7db-2806-4bb1-aec6-7131859401f7', '4792aa3a-96b6-4296-996e-44c1faf79d68', 'Male Urinals', NULL, '2025-06-25 20:19:34.373832+00', '2025-06-25 20:19:34.373832+00', false),
	('b02bb9e1-d3a1-4383-8275-886ebdf6bc86', '4792aa3a-96b6-4296-996e-44c1faf79d68', 'Bed Pans', NULL, '2025-06-25 20:19:43.297081+00', '2025-06-25 20:19:43.297081+00', false),
	('5045371f-efb5-4add-9353-b1741d83f3bf', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Keytone', NULL, '2025-06-26 00:06:37.209844+00', '2025-06-26 00:06:37.209844+00', false),
	('d6c176e9-ddbe-4884-b899-0f16f7eef288', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Glucose Strips', NULL, '2025-06-26 00:06:54.108513+00', '2025-06-26 00:06:54.108513+00', false),
	('ddcc2518-2bf4-4b6e-a1e9-c38c47a5eb01', '4792aa3a-96b6-4296-996e-44c1faf79d68', 'Consumable', NULL, '2025-06-26 23:04:32.49699+00', '2025-06-26 23:04:32.49699+00', false),
	('8589b36d-7d7e-4cf9-9956-34667f2f4069', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'Solution Pack', NULL, '2025-06-27 01:19:54.266022+00', '2025-06-27 01:19:54.266022+00', false),
	('3af07cde-49fa-48fc-b46a-4367a3850b9b', 'b864ed57-5547-404e-9459-1641a030974e', 'Ultrasound Machine', NULL, '2025-06-27 06:36:42.347087+00', '2025-06-27 06:36:42.347087+00', false);


--
-- Data for Name: department_task_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."department_task_assignments" ("id", "department_id", "task_type_id", "task_item_id", "created_at") VALUES
	('a409134d-ff8d-4669-b298-caee04c21a86', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 14:50:26.865921+00'),
	('b1d27130-5806-41f1-9cec-c47670b512d5', '8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 14:50:51.305825+00'),
	('da1128e3-7ecf-4684-b83c-e87316c57279', '9056ee14-242b-4208-a87d-fc59d24d442c', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '2025-06-11 14:51:16.895449+00'),
	('b2dd6756-f772-45b2-904b-69c96e6544ef', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '2025-06-11 14:51:32.185514+00'),
	('a839ea6f-cb73-4a59-bcfe-68173dfa1e88', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:51:48.062865+00'),
	('0ac90389-47f1-4995-bd19-2acd04864682', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:00.563566+00'),
	('aeffb87e-b1cf-4f24-863b-9779b39050c8', 'a2ef9aed-a412-42fc-9ca1-b8e571aa9da0', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:15.17909+00'),
	('1707f30b-e1e5-4060-b8d5-0055126a3a69', '571553c2-9f8f-4ec0-92ca-5c84f0379d0c', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:22.692509+00'),
	('d21c118b-113d-4f8a-acec-d177075a0073', '23199491-fe75-4c33-9cc8-1c86070cf0d1', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 14:52:34.421428+00'),
	('c89832ad-c3f9-4a6f-8704-9c52ed83fb00', 'ac2333d2-0b37-4924-a039-478caf702fbd', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:16:43.436747+00'),
	('1a08c8a5-76fc-42ec-8694-5edb6d72d6fb', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 15:17:10.751269+00'),
	('fce1f7e1-ed1b-472c-9563-8c1b66719e22', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:17:33.118989+00'),
	('222e730b-6d15-45d6-bc8c-a1268e2df90f', '4d4a725f-876e-449b-a1c6-cd4d6a50a637', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '5c0c9e25-ae34-4872-8696-4c4ce6e76112', '2025-06-11 15:17:42.772506+00'),
	('1ec876d6-011b-48b6-8c43-15890f281d4c', '831035d1-93e9-4683-af25-b40c2332b2fe', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:17:58.422893+00'),
	('7098334f-2f5f-49c8-8beb-c8e5f585ec81', 'c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2025-06-11 15:18:11.992868+00'),
	('d4832e21-9714-4c62-a001-5537258ae7f5', 'a8d3be01-4d46-41c1-b304-ab98610847e7', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '68e8e006-79dc-4d5f-aed0-20755d53403b', '2025-06-11 15:18:27.330724+00'),
	('24dbc56d-444b-4c3f-a94c-8ebcf231924e', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', '14446938-25cd-4655-ad84-dbb7db871f28', '2025-06-11 15:19:01.298706+00'),
	('106f1f05-ab88-4e8f-8d57-1be16322f985', '60c6f384-09d7-4ec8-bc90-b72fe1d82af9', 'a97d8a74-0e16-4e1f-908e-96e935d91002', '496c3b93-bc9c-4ea3-b022-aa2843d166e0', '2025-06-15 10:36:22.662145+00'),
	('886724d9-1bf4-47eb-ad7e-2ffac9674682', '167c7358-aa39-498e-b0b0-bda652b27401', 'a47856e2-f979-4dae-9444-472e548d4a96', 'a59c446d-7263-4733-93ce-5823448a5fde', '2025-06-15 14:27:18.025761+00'),
	('11faba13-9ae0-447c-92b4-4da86ada0694', '99d8db21-2c14-4f8f-8e54-54fc81004997', 'f286fc68-33ba-4c5a-98b8-ed7f24f8f59c', 'be835d6f-62c6-48bf-ae5f-5257e097349b', '2025-06-15 14:27:34.70466+00');


--
-- Data for Name: porter_absences; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."porter_absences" ("id", "porter_id", "absence_type", "start_date", "end_date", "created_at", "updated_at", "notes") VALUES
	('39946668-fb64-46dc-ade9-3e4e63482372', '7884c45a-823f-48c9-a4d4-fd2ad426f144', 'illness', '2025-06-03', '2025-06-10', '2025-06-03 15:55:02.824141+00', '2025-06-03 15:55:02.824141+00', ''),
	('4fb85cec-3dd5-445f-a301-21e82d5867dc', '2e74429e-2aab-4bed-a979-6ccbdef74596', 'annual_leave', '2025-06-03', '2025-06-05', '2025-06-03 16:19:50.491773+00', '2025-06-03 16:19:50.491773+00', 'Test'),
	('cd529b26-bdbf-4d1a-bd45-bb39862f6f8a', '296edb55-91eb-4d73-aa43-54840cbbf20c', 'annual_leave', '2025-06-03', '2025-06-06', '2025-06-03 16:46:24.129961+00', '2025-06-03 16:46:24.129961+00', 'Test 2'),
	('0269ce02-1315-42eb-843c-102a6ae52d14', '3316eda6-d5f5-445f-8721-b8c42e18d89c', 'illness', '2025-06-03', '2025-06-04', '2025-06-03 17:11:47.779144+00', '2025-06-03 17:11:47.779144+00', ''),
	('5b3ce846-6af6-4dfc-acf1-acd93b53573b', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', 'illness', '2025-06-04', '2025-06-05', '2025-06-03 17:46:24.707979+00', '2025-06-03 17:46:24.707979+00', '');


--
-- Data for Name: shifts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shifts" ("id", "supervisor_id", "shift_type", "start_time", "end_time", "is_active", "created_at", "updated_at", "shift_date") VALUES
	('e9a460ec-bd19-4176-a315-6633f200add7', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-25 01:01:31+00', '2025-06-25 01:38:45.146+00', false, '2025-06-25 01:01:32.97939+00', '2025-06-26 02:55:34.323111+00', '2025-06-25'),
	('d2fb94a3-ffa9-4696-975a-b74d27927c23', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-25 01:39:25+00', '2025-06-25 02:14:32.27+00', false, '2025-06-25 01:39:25.164645+00', '2025-06-26 02:55:34.323111+00', '2025-06-25'),
	('ae70fc9f-4831-45be-a314-1ef6cc5cc1ba', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-25 02:14:42+00', '2025-06-25 02:16:41.432+00', false, '2025-06-25 02:14:42.463323+00', '2025-06-26 02:55:34.323111+00', '2025-06-25'),
	('cc307153-0727-4d65-a47f-c8c3d007e1af', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-25 02:16:59+00', '2025-06-25 07:00:34.381+00', false, '2025-06-25 02:16:59.98318+00', '2025-06-26 02:55:34.323111+00', '2025-06-25'),
	('8e9345bb-939b-4ef8-a3ce-a35e396b921d', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-24 21:45:30+00', '2025-06-24 23:50:27.739+00', false, '2025-06-24 21:45:30.439638+00', '2025-06-26 02:55:34.323111+00', '2025-06-24'),
	('9ecdca87-4206-416b-9b84-f0b83cae1fad', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-25 18:06:30+00', '2025-06-26 07:12:05.102+00', false, '2025-06-25 18:06:30.337157+00', '2025-06-26 07:12:05.22771+00', '2025-06-25'),
	('d5bed006-83c4-4b75-8c23-1903df2f7324', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-26 19:00:00+00', '2025-06-26 19:03:44.98+00', false, '2025-06-26 18:56:27.13+00', '2025-06-26 19:03:45.592484+00', '2025-06-26'),
	('b7378cab-ab71-4158-a44e-e5724703aa11', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-26 19:00:00+00', '2025-06-26 22:11:41.589+00', false, '2025-06-26 19:04:14.012+00', '2025-06-26 22:11:41.970628+00', '2025-06-26'),
	('79dddcc3-f55f-495c-882c-2723d518248a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_night', '2025-06-26 19:00:00+00', '2025-06-30 15:38:28.063+00', false, '2025-06-26 22:11:53.739+00', '2025-06-30 15:38:28.327765+00', '2025-06-26'),
	('aedb6287-c44a-4f2e-8d40-1a32a98d307d', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-07-01 08:00:00+00', '2025-06-30 15:44:50.764+00', false, '2025-06-30 15:44:03.349+00', '2025-06-30 15:44:51.028176+00', '2025-07-01'),
	('8db2d484-414b-45b8-ab66-22ed95892d17', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-07-01 08:00:00+00', '2025-06-30 16:07:56.019+00', false, '2025-06-30 15:58:51.232+00', '2025-06-30 16:07:56.49615+00', '2025-07-01'),
	('ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '358aa759-e11e-40b0-b886-37481c5eb6c0', 'week_day', '2025-07-01 08:00:00+00', '2025-06-30 16:34:28.477+00', false, '2025-06-30 16:08:05.978+00', '2025-06-30 16:34:28.85447+00', '2025-07-01'),
	('06771608-e3ce-4212-bf21-f956fd68dc04', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'week_day', '2025-07-01 08:00:00+00', NULL, true, '2025-06-30 16:34:37.251+00', '2025-06-30 16:57:43.376949+00', '2025-07-01');


--
-- Data for Name: shift_area_cover_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_assignments" ("id", "shift_id", "department_id", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('ac9acee0-c328-4976-9628-bf1a8c9d4fcf', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-24 21:47:24.828642+00', '2025-06-24 21:47:24.828642+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f1317372-032e-4708-b54e-d4e7ea862074', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-24 21:48:18.305784+00', '2025-06-24 21:48:18.305784+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('34979b8a-3267-437e-9414-381c076161c5', 'e9a460ec-bd19-4176-a315-6633f200add7', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 01:01:32.97939+00', '2025-06-25 01:01:32.97939+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7f2ebbb9-ef80-4779-84ac-ac64518bc823', 'e9a460ec-bd19-4176-a315-6633f200add7', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 01:01:32.97939+00', '2025-06-25 01:01:32.97939+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a65ffd16-e21d-4565-8fb1-2085f54e1353', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 01:39:25.164645+00', '2025-06-25 01:39:25.164645+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fb68a37e-6347-481c-b286-0a8ae56fd19d', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 01:39:25.164645+00', '2025-06-25 01:39:25.164645+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('94fbeae4-2c56-4228-b9e1-ef9989a0f49f', 'ae70fc9f-4831-45be-a314-1ef6cc5cc1ba', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 02:14:42.463323+00', '2025-06-25 02:14:42.463323+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('899fc701-7bc6-4cb5-9bfb-874acfb3ebf4', 'ae70fc9f-4831-45be-a314-1ef6cc5cc1ba', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 02:14:42.463323+00', '2025-06-25 02:14:42.463323+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('d73425a5-1d2a-4956-95be-2b4522b58d80', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 02:16:59.98318+00', '2025-06-25 02:16:59.98318+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2f32041f-2af6-4b0a-b220-d58adf1f4e3b', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 02:16:59.98318+00', '2025-06-25 02:16:59.98318+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('06aea069-0c7d-4bb2-ae83-e400c8f21670', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 18:06:30.337157+00', '2025-06-25 18:06:30.337157+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e63fb86d-c88b-4bed-b56e-0eec33b719aa', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-25 18:06:30.337157+00', '2025-06-25 18:06:30.337157+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('b1d1d05a-41f9-46dc-9672-73978db7f61f', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-26 18:56:27.732752+00', '2025-06-26 18:56:27.732752+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e32eec9d-b332-4581-8e34-66f99601826d', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-26 18:56:27.732752+00', '2025-06-26 18:56:27.732752+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('787fd595-203c-4bdf-9b3e-71f6e3a8ff77', 'b7378cab-ab71-4158-a44e-e5724703aa11', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-26 19:04:14.599672+00', '2025-06-26 19:04:14.599672+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('623532dd-32fd-434c-9573-edc5ec825559', 'b7378cab-ab71-4158-a44e-e5724703aa11', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-26 19:04:14.599672+00', '2025-06-26 19:04:14.599672+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('37fdf8a0-bb8e-428d-81b6-980952cfa427', '79dddcc3-f55f-495c-882c-2723d518248a', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '20:00:00', '08:00:00', '#4285F4', '2025-06-26 22:11:54.238403+00', '2025-06-26 22:11:54.238403+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8c1fb9ae-4704-4ac8-b9c2-54f882008829', '79dddcc3-f55f-495c-882c-2723d518248a', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '20:00:00', '08:00:00', '#4285F4', '2025-06-26 22:11:54.238403+00', '2025-06-26 22:11:54.238403+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0d7305ce-e12f-43db-a3cb-d1993a99a748', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('1c9c1921-633d-443e-8de1-cec3fa8b7da6', '8db2d484-414b-45b8-ab66-22ed95892d17', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('57de54c0-b0de-4e40-9b21-99cb2845d94b', '8db2d484-414b-45b8-ab66-22ed95892d17', '81c30d93-8712-405c-ac5e-509d48fd9af9', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4df4bfb3-5a14-4403-99e9-b14eaa343594', '8db2d484-414b-45b8-ab66-22ed95892d17', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('932b6f5e-5c59-4d7c-8d67-84d44c21e90d', '8db2d484-414b-45b8-ab66-22ed95892d17', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4e8cb4f2-8a86-4261-b994-90c31e881cc3', '8db2d484-414b-45b8-ab66-22ed95892d17', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('010de906-6652-4138-b15f-2e046c75d156', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e51bb2c5-27ef-4b73-829c-e5f84bdc8fe6', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '81c30d93-8712-405c-ac5e-509d48fd9af9', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('031c9a98-7ec5-42bc-b93a-fb48634309bf', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('3fbc232d-aba4-4e94-9f4b-0af5d0b873fb', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('74447f56-9e5d-4e96-880c-d9e958998647', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0277a132-3689-4f80-ba68-31cd9280b22b', '06771608-e3ce-4212-bf21-f956fd68dc04', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('eaa3751e-115e-4da6-865d-1af42345222e', '06771608-e3ce-4212-bf21-f956fd68dc04', '81c30d93-8712-405c-ac5e-509d48fd9af9', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('0406149a-875c-4dbb-821c-841c2a6ea72f', '06771608-e3ce-4212-bf21-f956fd68dc04', 'f9d3bbce-8644-4075-8b80-457777f6d16c', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('fe4e2705-e377-43a8-a0f3-59a5fa02c1c4', '06771608-e3ce-4212-bf21-f956fd68dc04', '8269f3d0-fb22-415c-b235-7cf00c96f3b9', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('a3632ca6-4bac-4752-88b9-159ba1b6a037', '06771608-e3ce-4212-bf21-f956fd68dc04', '5bcc07fe-8ec9-43e4-acc5-4b44799cda03', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: shift_area_cover_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_area_cover_porter_assignments" ("id", "shift_area_cover_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at", "agreed_absence") VALUES
	('7d074dea-831e-4f5e-bbd1-2dd502bc562c', '0d7305ce-e12f-43db-a3cb-d1993a99a748', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('ffc0adfe-2902-4562-8faa-ac75d77c0050', '0d7305ce-e12f-43db-a3cb-d1993a99a748', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '13:00:00', '23:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('a3cbb0dc-b93a-42e8-8e26-deadde975fd8', '0d7305ce-e12f-43db-a3cb-d1993a99a748', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '09:00:00', '17:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('66d62c34-24ef-4b6d-bd1c-1e1dd9abe254', '1c9c1921-633d-443e-8de1-cec3fa8b7da6', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', NULL),
	('963c866c-539e-4ade-bd17-3a64224b0dc7', '1c9c1921-633d-443e-8de1-cec3fa8b7da6', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '13:00:00', '23:00:00', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', NULL),
	('e7aabfd6-7ca1-4170-a2d2-27d388e8db77', '932b6f5e-5c59-4d7c-8d67-84d44c21e90d', '7cc268aa-cb72-4320-ba8d-72f77b77dda6', '10:00:00', '18:00:00', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', NULL),
	('2035278c-5191-48ba-abef-c289ae844b22', '4e8cb4f2-8a86-4261-b994-90c31e881cc3', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', NULL),
	('695229c6-6ea5-4b2a-a7c6-9daa91181881', '010de906-6652-4138-b15f-2e046c75d156', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', NULL),
	('a88cba31-9dd4-44b6-84bb-76b2ce86cf8d', '010de906-6652-4138-b15f-2e046c75d156', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '13:00:00', '23:00:00', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', NULL),
	('f6cff41a-14ee-493c-ba3a-349eae73cf92', '3fbc232d-aba4-4e94-9f4b-0af5d0b873fb', '7cc268aa-cb72-4320-ba8d-72f77b77dda6', '10:00:00', '18:00:00', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', NULL),
	('622a396f-f17e-478f-9753-6fde96b34d56', '74447f56-9e5d-4e96-880c-d9e958998647', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', NULL),
	('a88eeabc-2835-46a6-b31f-cb1475eea8b4', '0277a132-3689-4f80-ba68-31cd9280b22b', '2e74429e-2aab-4bed-a979-6ccbdef74596', '14:00:00', '22:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('a437a8f4-e582-474e-82b9-7c1c3780df3e', '0277a132-3689-4f80-ba68-31cd9280b22b', 'bf79faf6-fb3e-4780-841e-63a4a67a5b77', '13:00:00', '23:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('06e4a966-5e3f-45b5-bf2a-058c19e6bafa', '34979b8a-3267-437e-9414-381c076161c5', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '20:00:00', '08:00:00', '2025-06-25 01:03:48.201173+00', '2025-06-25 01:03:48.201173+00', NULL),
	('334e21c6-fba1-474b-b9af-4032ea815a67', '7f2ebbb9-ef80-4779-84ac-ac64518bc823', 'af42f57f-1437-4320-b1a2-2b0051948de3', '20:00:00', '08:00:00', '2025-06-25 01:03:58.281673+00', '2025-06-25 01:03:58.281673+00', NULL),
	('ada9ce16-d714-4232-ac3f-cf1fa173ae73', 'a65ffd16-e21d-4565-8fb1-2085f54e1353', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '20:00:00', '08:00:00', '2025-06-25 01:46:06.02769+00', '2025-06-25 01:46:06.02769+00', NULL),
	('acf4a2fb-8b55-48c0-8098-2d950e12475e', '0277a132-3689-4f80-ba68-31cd9280b22b', 'ab2ba72f-ff0e-450d-a6a7-acf4d80fc235', '09:00:00', '17:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('ae2a6f5a-a521-42da-9616-d05cd02bc642', '0406149a-875c-4dbb-821c-841c2a6ea72f', '0655269c-b297-42e7-bdec-afb55cdee4d2', '08:00:00', '16:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('0d96b282-4647-4399-8174-b35b2ee55ecc', 'fb68a37e-6347-481c-b286-0a8ae56fd19d', 'af42f57f-1437-4320-b1a2-2b0051948de3', '20:00:00', '08:00:00', '2025-06-25 01:51:48.380457+00', '2025-06-25 01:51:48.380457+00', NULL),
	('0e32f4aa-f741-4f79-aed7-432ae4f16067', '0406149a-875c-4dbb-821c-841c2a6ea72f', '00e0ca67-f415-45ce-9b11-c3260e9cd58e', '09:00:00', '17:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('f128092d-a60e-44a6-9525-59269015fb26', 'fe4e2705-e377-43a8-a0f3-59a5fa02c1c4', 'df3f3a6d-23b5-4970-9ae0-47d458b84dd3', '09:00:00', '17:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('eeee14cd-0a05-4032-85f6-74e18258cf83', 'fe4e2705-e377-43a8-a0f3-59a5fa02c1c4', '7cc268aa-cb72-4320-ba8d-72f77b77dda6', '10:00:00', '18:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('0d80f9ae-5711-4c55-bf3a-4e0be1931b6b', 'a3632ca6-4bac-4752-88b9-159ba1b6a037', '74da0ff0-44aa-4fd5-a464-d25e45bea636', '08:30:00', '16:30:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('6a586a90-4d97-46fd-9fc0-bf0354fa89e9', 'a3632ca6-4bac-4752-88b9-159ba1b6a037', '0689dc61-6dcd-413d-a9f8-579fdc716757', '10:00:00', '18:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('4ea79de4-f0da-4464-a40c-a9ed4d8ab985', 'eaa3751e-115e-4da6-865d-1af42345222e', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '11:00:00', '19:00:00', '2025-06-30 16:43:56.16839+00', '2025-06-30 16:43:56.16839+00', NULL),
	('a37f5aaf-8fb0-493a-bd20-bbc13ce4f30c', 'fe4e2705-e377-43a8-a0f3-59a5fa02c1c4', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '17:00:00', '20:00:00', '2025-06-30 16:44:34.008243+00', '2025-06-30 16:44:34.008243+00', NULL);


--
-- Data for Name: shift_defaults; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_defaults" ("id", "shift_type", "start_time", "end_time", "color", "created_at", "updated_at") VALUES
	('85cc4d8d-f0fc-477a-b138-56efdcbfcdf1', 'week_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-06-26 22:11:22.352+00'),
	('524485d0-141a-4574-808b-93410f62ca94', 'weekend_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-06-26 22:11:22.353+00'),
	('2b13f0ba-98fc-4013-9953-0da1418e8ea0', 'weekend_day', '08:00:00', '20:00:00', '#4285F4', '2025-05-23 13:34:38.657478+00', '2025-06-26 22:11:22.353+00'),
	('01373b67-60e9-4422-a1ae-a8e72d119014', 'week_night', '20:00:00', '08:00:00', '#673AB7', '2025-05-23 13:34:38.657478+00', '2025-06-26 22:11:22.352+00');


--
-- Data for Name: shift_porter_absences; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: shift_porter_pool; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_porter_pool" ("id", "shift_id", "porter_id", "created_at", "updated_at", "is_supervisor") VALUES
	('bbfb61dd-c89a-447a-9682-f07d094fbcf3', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '2025-06-24 21:47:05.010407+00', '2025-06-24 21:47:05.010407+00', false),
	('a3e516f8-262d-4300-9090-23de12627d87', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-24 21:47:05.157407+00', '2025-06-24 21:47:05.157407+00', false),
	('558d1f21-27da-40e3-b0a8-84448dc13d06', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-06-24 21:56:31.551075+00', '2025-06-24 21:56:31.551075+00', false),
	('05702327-0a03-4b5d-86b4-a297abf8344b', 'e9a460ec-bd19-4176-a315-6633f200add7', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '2025-06-25 01:02:09.028359+00', '2025-06-25 01:02:09.028359+00', false),
	('97e4ff5e-e52f-49d7-b83e-d13342e23240', 'e9a460ec-bd19-4176-a315-6633f200add7', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-25 01:02:37.427588+00', '2025-06-25 01:02:37.427588+00', false),
	('d1b32fb8-4a05-4f02-8568-1a0a71ba4b3b', 'e9a460ec-bd19-4176-a315-6633f200add7', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-25 01:02:37.487934+00', '2025-06-25 01:02:37.487934+00', false),
	('57823da0-aa06-4838-b303-fbeef34b9bdf', 'e9a460ec-bd19-4176-a315-6633f200add7', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-06-25 01:02:37.545279+00', '2025-06-25 01:02:37.545279+00', false),
	('e3d0baf6-0b71-45cd-b0dc-a3e62a68185f', 'e9a460ec-bd19-4176-a315-6633f200add7', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-25 01:03:04.497074+00', '2025-06-25 01:03:04.497074+00', false),
	('c6d8a2d5-a4db-48e2-b4b9-2719741e3320', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-25 01:44:30.146263+00', '2025-06-25 01:44:30.146263+00', false),
	('c1fb73ac-e166-41a1-ad75-6402a419c3d6', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-25 01:44:43.427337+00', '2025-06-25 01:44:43.427337+00', false),
	('12956d6e-7f03-48e8-b856-ca08d9f06c79', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-25 01:45:12.841013+00', '2025-06-25 01:45:12.841013+00', false),
	('b6279e4a-9255-4a26-b5a7-d675d3694ed0', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '2025-06-25 01:45:27.480468+00', '2025-06-25 01:45:27.480468+00', false),
	('55c6c126-41ed-4716-8d56-7319a8962443', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-06-25 01:45:50.788026+00', '2025-06-25 01:45:50.788026+00', false),
	('8ba77f3f-d59e-4c51-8aa3-f68f1d15d06d', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2025-06-25 02:17:00.03016+00', '2025-06-25 02:17:00.03016+00', true),
	('308cc9b5-a256-496d-a803-7b707a9a62ed', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-25 02:51:44.652068+00', '2025-06-25 02:51:44.652068+00', false),
	('fefd75c3-8776-4c16-b533-f557a9f19cec', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-06-25 02:51:44.722807+00', '2025-06-25 02:51:44.722807+00', false),
	('9cb0af57-162d-4eb3-9d6a-88918a0643e5', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-25 02:51:44.787503+00', '2025-06-25 02:51:44.787503+00', false),
	('6f427687-0a51-488f-9536-29638da47c57', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '2025-06-25 02:51:44.870334+00', '2025-06-25 02:51:44.870334+00', false),
	('64d6157c-1343-497e-886e-d3f8e722892c', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-25 02:51:44.940909+00', '2025-06-25 02:51:44.940909+00', false),
	('5977c6e1-b970-44df-bdd4-26b7183d454d', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '1aaab277-ecf2-40dd-a764-eaaf8af7615b', '2025-06-25 03:24:14.450305+00', '2025-06-25 03:24:14.450305+00', false),
	('3ea3fe2e-6999-4666-b4a7-2ad13595cc96', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2025-06-25 18:06:30.504368+00', '2025-06-25 18:06:30.504368+00', true),
	('3552548c-bae4-4517-98f7-a424c9cc6641', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '1aaab277-ecf2-40dd-a764-eaaf8af7615b', '2025-06-25 18:12:27.0558+00', '2025-06-25 18:12:27.0558+00', false),
	('d219cdb5-8cba-44a0-beb0-bded20ce0272', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-25 18:12:27.121614+00', '2025-06-25 18:12:27.121614+00', false),
	('c8a3c5cb-59a2-4be0-9a62-fe23253451f7', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '2025-06-25 18:12:27.179443+00', '2025-06-25 18:12:27.179443+00', false),
	('bd3e61f9-a81b-40ba-a84d-3b5f8c6a465b', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-25 18:13:37.055533+00', '2025-06-25 18:13:37.055533+00', false),
	('59d8ac7f-7c05-4762-a203-5f4798d33791', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-25 18:14:27.532271+00', '2025-06-25 18:14:27.532271+00', false),
	('13e35924-edf3-4a3d-8eca-bb857080501f', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'b96a6ffa-6f54-4eab-a1c8-5c65dc7223da', '2025-06-25 18:26:35.912499+00', '2025-06-25 18:26:35.912499+00', false),
	('af612e8d-ca45-473c-942b-93814a5cef41', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '1f1e61c3-848c-441c-8b89-8a85e16285df', '2025-06-25 18:59:39.455057+00', '2025-06-25 18:59:39.455057+00', false),
	('b44bdabc-0b15-4843-9ace-24f61f179bdc', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '920b6b2f-18f0-4f27-b3b8-3b5760f6afc8', '2025-06-25 19:03:21.977123+00', '2025-06-25 19:03:21.977123+00', false),
	('c4a4910e-53ec-4e1c-b948-abc2deb268df', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2025-06-26 18:56:27.846121+00', '2025-06-26 18:56:27.846121+00', true),
	('3660ec34-fbc5-424a-aff2-1db666aa86e1', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-26 18:57:18.120011+00', '2025-06-26 18:57:18.120011+00', false),
	('d7a20062-714b-492d-ae29-f255ad2bff9a', 'd5bed006-83c4-4b75-8c23-1903df2f7324', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-26 18:57:18.18418+00', '2025-06-26 18:57:18.18418+00', false),
	('024a7559-8040-4cfa-af0e-c3650b85fb65', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '2025-06-26 18:57:18.262223+00', '2025-06-26 18:57:18.262223+00', false),
	('84846703-9c82-4222-89ee-ab877e298e71', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-26 18:57:18.338501+00', '2025-06-26 18:57:18.338501+00', false),
	('f527a624-cc81-4143-9f60-75aefb065019', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '1f1e61c3-848c-441c-8b89-8a85e16285df', '2025-06-26 18:57:18.387483+00', '2025-06-26 18:57:18.387483+00', false),
	('7efddea4-194e-4ae6-900f-bc8f5048f45a', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-06-26 18:57:18.470791+00', '2025-06-26 18:57:18.470791+00', false),
	('673c3326-cb93-48cf-9a06-afb6d79c5c10', 'b7378cab-ab71-4158-a44e-e5724703aa11', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2025-06-26 19:04:14.657843+00', '2025-06-26 19:04:14.657843+00', true),
	('e91d2def-f510-4851-b788-49ca370ce653', 'b7378cab-ab71-4158-a44e-e5724703aa11', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-26 19:04:25.830215+00', '2025-06-26 19:04:25.830215+00', false),
	('70962146-777c-42b0-8240-d728fe214025', 'b7378cab-ab71-4158-a44e-e5724703aa11', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-26 22:10:36.493108+00', '2025-06-26 22:10:36.493108+00', false),
	('731fd20d-ed72-4c96-a5d6-5e518710e632', 'b7378cab-ab71-4158-a44e-e5724703aa11', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-06-26 22:10:36.61216+00', '2025-06-26 22:10:36.61216+00', false),
	('b2873d75-6d59-40ab-905d-58543a39441c', '79dddcc3-f55f-495c-882c-2723d518248a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2025-06-26 22:11:54.357735+00', '2025-06-26 22:11:54.357735+00', true),
	('4826f267-81c7-4c52-b2a6-58380d305480', '79dddcc3-f55f-495c-882c-2723d518248a', '1f1e61c3-848c-441c-8b89-8a85e16285df', '2025-06-26 22:13:14.344354+00', '2025-06-26 22:13:14.344354+00', false),
	('316a314f-5870-405c-a4ed-09089748279a', '79dddcc3-f55f-495c-882c-2723d518248a', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '2025-06-26 22:13:14.472182+00', '2025-06-26 22:13:14.472182+00', false),
	('0fab5604-16d8-4943-a308-4999e68db7c1', '79dddcc3-f55f-495c-882c-2723d518248a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2025-06-26 22:13:14.590537+00', '2025-06-26 22:13:14.590537+00', false),
	('073efe2c-3617-4e84-b1d4-c3f5abe8c97d', '79dddcc3-f55f-495c-882c-2723d518248a', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2025-06-26 22:13:21.084338+00', '2025-06-26 22:13:21.084338+00', false),
	('722a31a8-060a-467a-b1ca-f96324c47452', '79dddcc3-f55f-495c-882c-2723d518248a', 'af42f57f-1437-4320-b1a2-2b0051948de3', '2025-06-27 02:13:22.107474+00', '2025-06-27 02:13:22.107474+00', false),
	('ef1ecb09-c5ae-4d25-a95a-fd1dd8321de3', '79dddcc3-f55f-495c-882c-2723d518248a', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-27 02:43:04.402014+00', '2025-06-27 02:43:04.402014+00', false),
	('fc426ab7-3cb6-467e-ae00-03696fc06272', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2025-06-30 15:44:03.767193+00', '2025-06-30 15:44:03.767193+00', true),
	('8bbf0323-457a-4a1f-8d56-936ca1bfeb0b', '8db2d484-414b-45b8-ab66-22ed95892d17', '358aa759-e11e-40b0-b886-37481c5eb6c0', '2025-06-30 15:58:51.592001+00', '2025-06-30 15:58:51.592001+00', true),
	('b3737aca-1ed1-448a-b4cf-db58a83c77e8', '8db2d484-414b-45b8-ab66-22ed95892d17', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '2025-06-30 16:00:07.369072+00', '2025-06-30 16:00:07.369072+00', false),
	('81b08c6b-f592-4b15-bb15-73ee9f20386f', '8db2d484-414b-45b8-ab66-22ed95892d17', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '2025-06-30 16:00:07.453161+00', '2025-06-30 16:00:07.453161+00', false),
	('15923714-a09a-440e-8bec-3ceb2082aec6', '8db2d484-414b-45b8-ab66-22ed95892d17', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '2025-06-30 16:02:16.554585+00', '2025-06-30 16:02:16.554585+00', false),
	('36b69cb4-a8a5-4b43-842b-4278e681add1', '8db2d484-414b-45b8-ab66-22ed95892d17', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '2025-06-30 16:02:16.628649+00', '2025-06-30 16:02:16.628649+00', false),
	('32af02e4-03e8-4d15-8f96-605f79bb64a9', '8db2d484-414b-45b8-ab66-22ed95892d17', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '2025-06-30 16:02:16.714909+00', '2025-06-30 16:02:16.714909+00', false),
	('7d0fde6d-d4c2-4e19-88b8-74ba109559e5', '8db2d484-414b-45b8-ab66-22ed95892d17', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '2025-06-30 16:02:16.809457+00', '2025-06-30 16:02:16.809457+00', false),
	('2b507a53-8ef0-4b66-8793-c5151fba6caa', '8db2d484-414b-45b8-ab66-22ed95892d17', '1a21db6c-9a35-48ca-a3b0-06284bec8beb', '2025-06-30 16:02:16.903991+00', '2025-06-30 16:02:16.903991+00', false),
	('9e93b765-6bba-4b21-9341-8967e2fdd4d9', '8db2d484-414b-45b8-ab66-22ed95892d17', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '2025-06-30 16:02:16.9911+00', '2025-06-30 16:02:16.9911+00', false),
	('09351f02-118f-4127-9faa-8de28a7dfb3f', '8db2d484-414b-45b8-ab66-22ed95892d17', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-30 16:03:10.279022+00', '2025-06-30 16:03:10.279022+00', false),
	('905e52aa-5db8-448e-8f4d-a8e55f6dbf99', '8db2d484-414b-45b8-ab66-22ed95892d17', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '2025-06-30 16:04:02.228937+00', '2025-06-30 16:04:02.228937+00', false),
	('25a7d507-bc86-4222-b26f-0186a253301e', '8db2d484-414b-45b8-ab66-22ed95892d17', 'fabfccff-9e98-4965-83c2-97f388a7672e', '2025-06-30 16:04:02.307854+00', '2025-06-30 16:04:02.307854+00', false),
	('cd9792ff-2e8b-4708-a788-d6a02e5fc7cc', '8db2d484-414b-45b8-ab66-22ed95892d17', 'c965e4e3-e132-43f0-94ce-1b41d33a9f05', '2025-06-30 16:04:02.37475+00', '2025-06-30 16:04:02.37475+00', false),
	('b8d85329-69f3-4af0-afdc-79274bbc28c4', '8db2d484-414b-45b8-ab66-22ed95892d17', '920b6b2f-18f0-4f27-b3b8-3b5760f6afc8', '2025-06-30 16:04:02.447186+00', '2025-06-30 16:04:02.447186+00', false),
	('898071c9-e37d-4e4a-b7e0-0e80490f0654', '8db2d484-414b-45b8-ab66-22ed95892d17', '6e772f6a-e4e8-422a-b21b-ff677b625471', '2025-06-30 16:04:02.528932+00', '2025-06-30 16:04:02.528932+00', false),
	('389407d5-b198-4808-8378-c954c9177d35', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '358aa759-e11e-40b0-b886-37481c5eb6c0', '2025-06-30 16:08:06.331284+00', '2025-06-30 16:08:06.331284+00', true),
	('b88c3691-3be0-44d5-9bd4-68615aecf88c', '06771608-e3ce-4212-bf21-f956fd68dc04', '358aa759-e11e-40b0-b886-37481c5eb6c0', '2025-06-30 16:34:37.648515+00', '2025-06-30 16:34:37.648515+00', true),
	('93fc3837-7bac-4d81-ba40-4da816cdd6a3', '06771608-e3ce-4212-bf21-f956fd68dc04', '6592897b-b9fb-4b02-a5d5-7fd0ab4fcb2e', '2025-06-30 16:42:16.743542+00', '2025-06-30 16:42:16.743542+00', false),
	('9671bc80-82d4-40b2-81a8-bfb4e46549af', '06771608-e3ce-4212-bf21-f956fd68dc04', 'c162858c-9815-43e3-9bcb-0c709bd8eef0', '2025-06-30 16:42:16.879852+00', '2025-06-30 16:42:16.879852+00', false),
	('75f0c4fd-400a-406e-a84b-69ad3e8f781a', '06771608-e3ce-4212-bf21-f956fd68dc04', '2ef290c6-6c61-4d37-be45-d08ae6afc097', '2025-06-30 16:42:16.96797+00', '2025-06-30 16:42:16.96797+00', false),
	('3ca65a4b-b4ab-4d15-a4b7-848bdfa91620', '06771608-e3ce-4212-bf21-f956fd68dc04', 'c3052ff8-8339-4e02-b4ed-efee9365e7c2', '2025-06-30 16:42:17.069454+00', '2025-06-30 16:42:17.069454+00', false),
	('092c0db4-1b75-452c-a917-6d3e3a2a0d83', '06771608-e3ce-4212-bf21-f956fd68dc04', '80d77d87-0ab0-4a96-9dc8-8e23a5020ce2', '2025-06-30 16:42:17.159431+00', '2025-06-30 16:42:17.159431+00', false),
	('dc9a4ad5-d0ec-4ad9-8ee8-0aa8906a6a55', '06771608-e3ce-4212-bf21-f956fd68dc04', '6ea8a4e6-b931-4ae0-acac-2fac2f23cfe2', '2025-06-30 16:42:17.244288+00', '2025-06-30 16:42:17.244288+00', false),
	('bebfbc9c-204b-43a0-8f0a-d2c10b1c2d56', '06771608-e3ce-4212-bf21-f956fd68dc04', '1a21db6c-9a35-48ca-a3b0-06284bec8beb', '2025-06-30 16:42:17.322365+00', '2025-06-30 16:42:17.322365+00', false),
	('4fe6f5ef-d6ea-40a3-8596-83275a2cb8d9', '06771608-e3ce-4212-bf21-f956fd68dc04', 'e9cf3a23-c94a-409b-aa71-d42602e54068', '2025-06-30 16:42:17.396069+00', '2025-06-30 16:42:17.396069+00', false),
	('bc2f39b0-96b5-42dd-857a-b49d47040624', '06771608-e3ce-4212-bf21-f956fd68dc04', '63f5c89b-661d-40e5-a810-7fba772d4dc5', '2025-06-30 16:42:17.468271+00', '2025-06-30 16:42:17.468271+00', false),
	('3b91343f-251d-40b9-80c1-873d2c6f4d3f', '06771608-e3ce-4212-bf21-f956fd68dc04', 'f233a4cb-cd6d-4c6a-8fd6-01eea72a9fb0', '2025-06-30 16:42:17.542309+00', '2025-06-30 16:42:17.542309+00', false),
	('728d4c65-c6f2-43e7-93fb-2679abd28492', '06771608-e3ce-4212-bf21-f956fd68dc04', 'fabfccff-9e98-4965-83c2-97f388a7672e', '2025-06-30 16:42:17.656182+00', '2025-06-30 16:42:17.656182+00', false),
	('ee0e5e03-47e2-42bc-a6e7-d67e257e9313', '06771608-e3ce-4212-bf21-f956fd68dc04', 'c965e4e3-e132-43f0-94ce-1b41d33a9f05', '2025-06-30 16:42:17.727218+00', '2025-06-30 16:42:17.727218+00', false),
	('a4d4a4bb-db97-426b-8402-fbc6c7505eef', '06771608-e3ce-4212-bf21-f956fd68dc04', '920b6b2f-18f0-4f27-b3b8-3b5760f6afc8', '2025-06-30 16:42:17.802349+00', '2025-06-30 16:42:17.802349+00', false),
	('c4dfd203-0630-436e-b2b0-98c63941abab', '06771608-e3ce-4212-bf21-f956fd68dc04', '6e772f6a-e4e8-422a-b21b-ff677b625471', '2025-06-30 16:42:17.868075+00', '2025-06-30 16:42:17.868075+00', false),
	('1a4b384e-b3d6-4689-979c-828618cb87d8', '06771608-e3ce-4212-bf21-f956fd68dc04', '4e543605-21a0-4373-8434-7f9809abea33', '2025-06-30 16:42:17.926901+00', '2025-06-30 16:42:17.926901+00', false);


--
-- Data for Name: shift_support_service_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_assignments" ("id", "shift_id", "service_id", "start_time", "end_time", "color", "created_at", "updated_at", "minimum_porters", "minimum_porters_mon", "minimum_porters_tue", "minimum_porters_wed", "minimum_porters_thu", "minimum_porters_fri", "minimum_porters_sat", "minimum_porters_sun") VALUES
	('2ec5eae4-ffdf-4d74-bfb1-ef65a09e41db', 'd2fb94a3-ffa9-4696-975a-b74d27927c23', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-25 01:39:25.164645+00', '2025-06-25 01:39:25.164645+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('119c253b-d70a-466c-96ef-34312fd861e7', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-25 02:16:59.98318+00', '2025-06-25 02:16:59.98318+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('90a0dcf9-8069-4938-a22d-6f3a3e7c944f', 'b7378cab-ab71-4158-a44e-e5724703aa11', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-26 19:04:14.599672+00', '2025-06-26 19:04:14.599672+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('3a6628a6-0b1e-48be-8ffc-e615c5b50310', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('09112b1a-4211-4e84-83f4-2d0d27eb59bb', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('fa602460-d73f-41ef-bd89-7832184c3c7b', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7cb5eafc-5318-4574-b810-972f6ed48e4c', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('eed45b4a-5d56-4a57-a923-f100b0381c59', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('6c82ac45-ab9a-4f2c-b920-535953addc48', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('995f2f85-a4e1-434c-b6e6-e976635073c2', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('9608694c-7bb0-4d8b-8e2d-0fcb34c62ac7', 'aedb6287-c44a-4f2e-8d40-1a32a98d307d', '976ec471-fd8c-450e-a2ce-5b51993e502c', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('7d885d48-45ac-488e-8e75-0133c5979b53', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('3c23bc36-c2fa-44f7-accd-e0d6b920fb8a', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('067a6c95-ffe0-4603-b8d6-2e70f48837f6', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('2945b9e9-5ddb-4075-9faf-bb2179a43209', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('3b13e4ed-9d0e-440d-8e06-41c575625893', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('bd909249-36db-46c6-830e-071a5183b172', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('0bf403d4-95ba-460d-a070-fa20981a8640', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('6ea6d456-6983-4f67-88d1-e72304c9ac41', 'ce859bcc-7e2f-49db-b33a-886cc6fbf60c', '976ec471-fd8c-450e-a2ce-5b51993e502c', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('cfc082db-8c44-4625-a1cf-0a6b5a28b85b', 'e9a460ec-bd19-4176-a315-6633f200add7', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-25 01:01:32.97939+00', '2025-06-25 01:01:32.97939+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('c0326ee2-ba1d-4002-b0cc-582db60b77ae', 'ae70fc9f-4831-45be-a314-1ef6cc5cc1ba', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-25 02:14:42.463323+00', '2025-06-25 02:14:42.463323+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('66353586-6c06-4c4c-8a50-dd15521beb62', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-25 18:06:30.337157+00', '2025-06-25 18:06:30.337157+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('37490612-ccd5-4bf7-b5c3-7a8a7e6e3fe8', 'd5bed006-83c4-4b75-8c23-1903df2f7324', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-26 18:56:27.732752+00', '2025-06-26 18:56:27.732752+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('949392a5-6220-4f18-9d61-5f4064ad0d58', '79dddcc3-f55f-495c-882c-2723d518248a', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-26 22:11:54.238403+00', '2025-06-26 22:11:54.238403+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('5aee31df-7211-486d-85a6-2a9d16a74bce', '8db2d484-414b-45b8-ab66-22ed95892d17', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('f2bd1d9b-730b-4b87-9d0b-0caf4c7485c1', '8db2d484-414b-45b8-ab66-22ed95892d17', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4cc475a3-bb58-49d6-8d6e-2f5fcda3435e', '8db2d484-414b-45b8-ab66-22ed95892d17', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('8a72a108-7d04-4216-9738-4f1ba6ce5cc3', '8db2d484-414b-45b8-ab66-22ed95892d17', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('927bda07-a738-49ac-8075-5dd9cde15bbc', '8db2d484-414b-45b8-ab66-22ed95892d17', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('433d2667-25df-46be-aa9b-be29c05d5631', '8db2d484-414b-45b8-ab66-22ed95892d17', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('85d2fcb8-7e15-496f-ac75-4e80834e4632', '8db2d484-414b-45b8-ab66-22ed95892d17', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('ee8d5454-7b73-407d-ab1e-faf583dcd47f', '8db2d484-414b-45b8-ab66-22ed95892d17', '976ec471-fd8c-450e-a2ce-5b51993e502c', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('95ff7e81-61b7-48fd-878c-78837bd4c6db', '06771608-e3ce-4212-bf21-f956fd68dc04', '26c0891b-56c0-4346-8d53-de906aaa64c2', '08:00:00', '16:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('237c12ea-eb57-4abf-97e6-35f4e36a9836', '06771608-e3ce-4212-bf21-f956fd68dc04', '0b5c7062-1285-4427-8387-b1b4e14eedc9', '15:00:00', '20:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('e8984eed-2b80-4846-be64-45dbc20a79a7', '06771608-e3ce-4212-bf21-f956fd68dc04', 'ce940139-6ae7-49de-a62a-0d6ba9397928', '09:00:00', '17:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('f0bf0516-4dd6-4fa8-8259-d98ceba73291', '06771608-e3ce-4212-bf21-f956fd68dc04', 'ca184e50-8bfa-4d61-b950-c1ba8e65a7a7', '08:30:00', '17:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 4, 4, 4, 4, 4, 4, 4, 4),
	('7dd9a7a9-f49d-46e2-840c-40ddad8bec25', '06771608-e3ce-4212-bf21-f956fd68dc04', '2ad13a8b-6ea2-4926-ad4a-64c74d686658', '07:00:00', '15:00:00', '#c8a76f', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('4d4610cf-ff74-48ce-9cf8-eead7bd3cba0', '06771608-e3ce-4212-bf21-f956fd68dc04', '30c5c045-a442-4ec8-b285-c7bc010f4d83', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('88a9adaf-d86b-4c7c-8086-48f939145331', '06771608-e3ce-4212-bf21-f956fd68dc04', '7cfa1ddf-61b0-489e-ad23-b924cf995419', '07:00:00', '15:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 2, 2, 2, 2, 2, 2, 2, 2),
	('3f93ee7c-f3f8-4469-9a34-5835ce1ca9cb', '06771608-e3ce-4212-bf21-f956fd68dc04', '976ec471-fd8c-450e-a2ce-5b51993e502c', '08:00:00', '20:00:00', '#4285F4', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', 1, 1, 1, 1, 1, 1, 1, 1),
	('59834881-4873-4c42-b410-8abeee09f6a3', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '976ec471-fd8c-450e-a2ce-5b51993e502c', '20:00:00', '01:00:00', '#4285F4', '2025-06-24 21:45:30.439638+00', '2025-06-24 21:45:30.439638+00', 1, 1, 1, 1, 1, 1, 1, 1);


--
-- Data for Name: shift_support_service_porter_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_support_service_porter_assignments" ("id", "shift_support_service_assignment_id", "porter_id", "start_time", "end_time", "created_at", "updated_at", "agreed_absence") VALUES
	('25289695-4f7b-49ff-be12-abdf13397e1b', '95ff7e81-61b7-48fd-878c-78837bd4c6db', '2524b1c5-45e1-4f15-bf3b-984354f22cdc', '08:00:00', '16:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('1bbba671-7556-485a-9d2b-3367e2c64aba', '95ff7e81-61b7-48fd-878c-78837bd4c6db', 'f304fa99-8e00-48d0-a616-d156b0f7484d', '08:00:00', '16:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('2f0fd435-f185-4e5e-92cd-72e7d8fe79b9', '119c253b-d70a-466c-96ef-34312fd861e7', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '20:00:00', '21:00:00', '2025-06-25 06:13:53.822617+00', '2025-06-25 06:13:53.822617+00', NULL),
	('126e01ba-1588-4266-b275-c237f5324672', '95ff7e81-61b7-48fd-878c-78837bd4c6db', '7c20aec3-bf78-4ef9-b35e-429e41ac739b', '08:00:00', '16:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('21508f9d-38e1-47f6-ae6e-5a024b4faa53', '237c12ea-eb57-4abf-97e6-35f4e36a9836', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('ecabe363-afb2-4aa1-be7d-494775f16284', 'e8984eed-2b80-4846-be64-45dbc20a79a7', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('2bce099b-a42e-498b-baba-fbf0da7c40e1', 'e8984eed-2b80-4846-be64-45dbc20a79a7', '4fb21c6f-2f5b-4f6e-b727-239a3391092a', '08:00:00', '16:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('eca65be5-42a4-455e-9d48-49066702864d', 'f0bf0516-4dd6-4fa8-8259-d98ceba73291', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('bbea8421-4b60-48b8-a2dd-09e196b7412c', 'f0bf0516-4dd6-4fa8-8259-d98ceba73291', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('26383ab5-1669-4dd0-adeb-6fbc9bc146b0', 'f0bf0516-4dd6-4fa8-8259-d98ceba73291', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('bf561d22-d30d-49f6-b085-7a0eea26fada', 'f0bf0516-4dd6-4fa8-8259-d98ceba73291', '7a905342-f7d6-4105-b56f-d922e86dbbd9', '08:30:00', '16:30:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('b5657c84-c996-4557-877a-0dd75e500490', '7dd9a7a9-f49d-46e2-840c-40ddad8bec25', '56d5a952-a958-41c5-aa28-bd42e06720c8', '07:00:00', '15:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('eaab2564-9b76-4543-8c15-8613a804dffa', '7dd9a7a9-f49d-46e2-840c-40ddad8bec25', '394d8660-7946-4b31-87c9-b60f7e1bc294', '07:00:00', '15:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('9799f70f-6de3-4b72-ad1e-f5c3c022097f', '4d4610cf-ff74-48ce-9cf8-eead7bd3cba0', '3316eda6-d5f5-445f-8721-b8c42e18d89c', '07:00:00', '15:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('d8839107-e7ee-4bee-9f4e-f8a61dfc704c', '4d4610cf-ff74-48ce-9cf8-eead7bd3cba0', '2fe13155-0425-4634-b42a-04380ff73ad1', '07:00:00', '15:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('4c3ec410-8666-4d2b-8d74-ec0e7101647a', '88a9adaf-d86b-4c7c-8086-48f939145331', '8daf3b6b-4e59-4445-ac27-397d1bc7854d', '07:00:00', '15:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('80b1a722-fa91-40c2-ad9f-d11897831d9e', '88a9adaf-d86b-4c7c-8086-48f939145331', 'b30280c2-aecc-4953-a1df-5f703bce4772', '07:00:00', '15:00:00', '2025-06-30 16:34:37.585562+00', '2025-06-30 16:34:37.585562+00', NULL),
	('a58dee60-0709-494f-8802-f83cae3b1616', '09112b1a-4211-4e84-83f4-2d0d27eb59bb', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('1c61eb48-c83a-4f7a-8d8b-3751cf5a6011', 'fa602460-d73f-41ef-bd89-7832184c3c7b', '394d8660-7946-4b31-87c9-b60f7e1bc294', '09:00:00', '17:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('145821f4-e779-44b9-870c-d9147d4e8022', '7cb5eafc-5318-4574-b810-972f6ed48e4c', 'c3579d99-b97e-4019-b37a-f63515fe3ca4', '09:00:00', '17:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('6fa275d2-e482-483d-aa1b-fa78320a18b1', '7cb5eafc-5318-4574-b810-972f6ed48e4c', '035ad40e-3ca6-4ce0-ab96-8590bd0b7f3f', '09:00:00', '17:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('9d9889d1-46af-4c5d-b5e6-151440ab8e46', '7cb5eafc-5318-4574-b810-972f6ed48e4c', 'ac5427be-ea01-4f42-9c46-17e2f089dee8', '09:00:00', '17:00:00', '2025-06-30 15:44:03.622429+00', '2025-06-30 15:44:03.622429+00', NULL),
	('9bf44908-3420-4e82-95ef-10e796639ffa', 'f2bd1d9b-730b-4b87-9d0b-0caf4c7485c1', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-30 15:58:51.516627+00', '2025-06-30 15:58:51.516627+00', NULL),
	('5075eb32-a5e1-4035-ac9f-5079014201fe', '3c23bc36-c2fa-44f7-accd-e0d6b920fb8a', 'c30cc891-1722-404f-9b84-14ffcee8d93f', '15:00:00', '20:00:00', '2025-06-30 16:08:06.264649+00', '2025-06-30 16:08:06.264649+00', NULL);


--
-- Data for Name: shift_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."shift_tasks" ("id", "shift_id", "task_item_id", "porter_id", "origin_department_id", "destination_department_id", "status", "created_at", "updated_at", "time_received", "time_allocated", "time_completed") VALUES
	('66d81e14-a81f-4570-892e-09a95ea5ecc5', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'completed', '2025-06-24 21:50:42.397178+00', '2025-06-24 21:50:42.397178+00', '2025-06-24T22:50:00', '2025-06-24T22:51:00', '2025-06-24T23:13:00'),
	('025cb139-865c-45b2-9e3d-9da9efee49a0', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, 'ccb6bf8f-275c-4d24-8907-09b97cbe0eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-24 21:51:25.936611+00', '2025-06-24 21:51:25.936611+00', '2025-06-24T22:50:00', '2025-06-24T22:51:00', '2025-06-24T23:16:00'),
	('145b56bb-0e55-48a1-ae14-3b5a72c44e13', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '23199491-fe75-4c33-9cc8-1c86070cf0d1', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-24 21:52:13.68206+00', '2025-06-24 21:52:13.68206+00', '2025-06-24T22:51:00', '2025-06-24T22:52:00', '2025-06-24T23:21:00'),
	('0098df0a-f729-4642-8c1f-c3406d24aa8a', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '81e0d17c-740a-4a00-9727-81d222f96234', NULL, 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '969a27a7-f5e5-4c23-b018-128aa2000b97', 'completed', '2025-06-24 21:52:36.294871+00', '2025-06-24 21:52:36.294871+00', '2025-06-24T22:52:00', '2025-06-24T22:53:00', '2025-06-24T23:14:00'),
	('ce27ea1d-072e-407e-b0ca-0f01a0f02867', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '68e8e006-79dc-4d5f-aed0-20755d53403b', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '6dc82d06-d4d2-4824-9a83-d89b583b7554', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-06-24 21:53:05.299608+00', '2025-06-24 21:53:05.299608+00', '2025-06-24T22:52:00', '2025-06-24T22:53:00', '2025-06-24T23:21:00'),
	('3668f30e-ff68-4aa4-a6be-4fcd4b2f6d40', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'completed', '2025-06-24 21:53:24.853042+00', '2025-06-24 21:53:24.853042+00', '2025-06-24T22:53:00', '2025-06-24T22:54:00', '2025-06-24T23:08:00'),
	('c78d056b-4ec5-45aa-89c1-9a6730562a6f', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', NULL, '7babbb12-15f9-4483-8b05-61220ed37167', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-24 21:53:55.568527+00', '2025-06-24 21:53:55.568527+00', '2025-06-24T22:53:00', '2025-06-24T22:54:00', '2025-06-24T23:11:00'),
	('3c0cb11a-6419-4ce8-82d2-62c2012f6846', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '14446938-25cd-4655-ad84-dbb7db871f28', NULL, '81c30d93-8712-405c-ac5e-509d48fd9af9', '0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'completed', '2025-06-24 21:54:31.578105+00', '2025-06-24 21:54:31.578105+00', '2025-06-24T22:53:00', '2025-06-24T22:54:00', '2025-06-24T23:09:00'),
	('d82ef078-db35-43fc-9cb6-c1e3616f17f1', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'e5e84800-eb11-4889-bb97-39ea75ef5190', NULL, 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '9dae2f86-2058-4c9c-a428-76f5648553d3', 'completed', '2025-06-24 21:57:36.255148+00', '2025-06-24 21:57:36.255148+00', '2025-06-24T22:56:00', '2025-06-24T22:57:00', '2025-06-24T23:21:00'),
	('b31bc24c-bed0-4573-917c-f320295aa9ac', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'completed', '2025-06-24 21:58:12.347137+00', '2025-06-24 21:58:12.347137+00', '2025-06-24T22:57:00', '2025-06-24T22:58:00', '2025-06-24T23:12:00'),
	('198edede-3c02-4480-9913-69fd00b9fb0a', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-24 21:59:02.095263+00', '2025-06-24 21:59:02.095263+00', '2025-06-24T22:58:00', '2025-06-24T22:59:00', '2025-06-24T23:18:00'),
	('30c5d8f2-f222-46c1-90bc-bc9512285e56', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '68e8e006-79dc-4d5f-aed0-20755d53403b', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '81c30d93-8712-405c-ac5e-509d48fd9af9', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-24 21:59:20.966824+00', '2025-06-24 21:59:20.966824+00', '2025-06-24T22:59:00', '2025-06-24T23:00:00', '2025-06-24T23:26:00'),
	('8c3b6542-39ea-4522-a874-e1ae5d0b36e1', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'a59c446d-7263-4733-93ce-5823448a5fde', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '167c7358-aa39-498e-b0b0-bda652b27401', '167c7358-aa39-498e-b0b0-bda652b27401', 'completed', '2025-06-24 21:59:52.097464+00', '2025-06-24 21:59:52.097464+00', '2025-06-24T22:59:00', '2025-06-24T23:00:00', '2025-06-24T23:18:00'),
	('19021d2a-0f3a-43ee-9361-ba48b347a44c', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '68e8e006-79dc-4d5f-aed0-20755d53403b', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'a189c856-581e-4d86-9dc2-de6995be4a3a', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'completed', '2025-06-24 22:00:53.08346+00', '2025-06-24 22:00:53.08346+00', '2025-06-24T22:59:00', '2025-06-24T23:00:00', '2025-06-24T23:24:00'),
	('75015a41-67a7-4cee-ab2a-4ff54aea3ea8', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '1e2a9593-d001-4da8-b020-0081d0492468', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '2aaff65e-ca83-42ce-961f-802b7a0137ab', '2aaff65e-ca83-42ce-961f-802b7a0137ab', 'completed', '2025-06-24 22:02:44.738682+00', '2025-06-24 22:02:44.738682+00', '2025-06-24T23:01:00', '2025-06-24T23:02:00', '2025-06-24T23:28:00'),
	('10a5db27-bba0-4042-b3b0-8016418721b0', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'a183cb03-10ec-4dff-8f0d-fafbd4e98ee1', NULL, 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'completed', '2025-06-24 23:43:05.593406+00', '2025-06-24 23:43:05.593406+00', '2025-06-24T23:18:00', '2025-06-24T23:19:00', '2025-06-24T23:38:00'),
	('c3c79131-9d57-488f-86b6-d7aa7abd0a19', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '68e8e006-79dc-4d5f-aed0-20755d53403b', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-24 23:43:34.080593+00', '2025-06-24 23:43:34.080593+00', '2025-06-24T00:43:00', '2025-06-24T00:44:00', '2025-06-24T01:12:00'),
	('f460bff0-015f-4d5d-83d8-b5b62c300b41', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', 'ee6c4e53-bcfa-4271-b0d5-dc61a5d0427c', NULL, 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '02c59898-fa58-4b51-b446-7f68dfa1bb9e', 'completed', '2025-06-24 23:44:52.963631+00', '2025-06-24 23:44:52.963631+00', '2025-06-24T00:43:00', '2025-06-24T00:44:00', '2025-06-24T00:59:00'),
	('ecf9021e-1904-4d47-a468-1a2f93471718', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '68e8e006-79dc-4d5f-aed0-20755d53403b', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '81c30d93-8712-405c-ac5e-509d48fd9af9', '569e9211-d394-4e93-ba3e-34ad20d98af4', 'completed', '2025-06-24 23:45:29.369152+00', '2025-06-24 23:45:29.369152+00', '2025-06-24T00:45:00', '2025-06-24T00:46:00', '2025-06-24T01:09:00'),
	('893cc0ad-d06d-4383-b620-7ca56865c257', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '14446938-25cd-4655-ad84-dbb7db871f28', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-06-24 23:46:02.101935+00', '2025-06-24 23:46:02.101935+00', '2025-06-24T00:45:00', '2025-06-24T00:46:00', '2025-06-24T01:12:00'),
	('ed48382e-8f3e-4f1b-9d40-d393fc9c9cb3', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '8a02eaa0-61c8-4c3c-846a-d723e27cd408', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'completed', '2025-06-24 23:46:50.642079+00', '2025-06-24 23:46:50.642079+00', '2025-06-24T00:46:00', '2025-06-24T00:47:00', '2025-06-24T01:06:00'),
	('663092eb-d598-46c7-809f-116a0716ad90', '8e9345bb-939b-4ef8-a3ce-a35e396b921d', '68e8e006-79dc-4d5f-aed0-20755d53403b', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '831035d1-93e9-4683-af25-b40c2332b2fe', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'completed', '2025-06-24 23:47:16.253929+00', '2025-06-24 23:47:16.253929+00', '2025-06-24T00:46:00', '2025-06-24T00:47:00', '2025-06-24T01:05:00'),
	('c2c4bccb-377d-494b-b5a2-f1cbd7f4dcbe', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'ccb6bf8f-275c-4d24-8907-09b97cbe0eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 02:21:23.583321+00', '2025-06-25 02:21:23.583321+00', '2025-06-25T03:20:00', '2025-06-25T03:21:00', '2025-06-25T03:42:00'),
	('13a82806-d0ee-4ee1-8b23-948f13ddccb2', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 03:07:54.022586+00', '2025-06-25 03:07:54.022586+00', '2025-06-25T04:07:00', '2025-06-25T04:08:00', '2025-06-25T04:27:00'),
	('cd4e3022-89ae-4706-9488-45b5a9f61538', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'completed', '2025-06-25 03:14:22.738577+00', '2025-06-25 03:15:07.988386+00', '20:09', '20:10', '20:24'),
	('adcc1272-aa2a-455a-8cd8-a1f22b3c70ab', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'ccb6bf8f-275c-4d24-8907-09b97cbe0eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 03:15:55.394382+00', '2025-06-25 03:15:55.394382+00', '2025-06-25T20:15:00', '2025-06-25T20:16:00', '2025-06-25T20:37:00'),
	('3df60805-12ac-47ad-bcd9-04d7ac36d12d', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 03:16:19.659814+00', '2025-06-25 03:16:44.255243+00', '20:15', '20:16', '20:38'),
	('9362c24f-3da6-4178-b668-63e537606f0a', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '81e0d17c-740a-4a00-9727-81d222f96234', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '969a27a7-f5e5-4c23-b018-128aa2000b97', 'completed', '2025-06-25 03:17:11.39564+00', '2025-06-25 03:17:11.39564+00', '2025-06-25T04:16:00', '2025-06-25T04:17:00', '2025-06-25T04:33:00'),
	('6ec36aba-562d-43e5-9848-90fe155069bd', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '6dc82d06-d4d2-4824-9a83-d89b583b7554', '831035d1-93e9-4683-af25-b40c2332b2fe', 'completed', '2025-06-25 03:17:43.110176+00', '2025-06-25 03:18:23.03015+00', '20:32', '20:33', '20:53'),
	('04047869-b4b3-444e-9705-faae540ab2ad', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'completed', '2025-06-25 03:19:15.956946+00', '2025-06-25 03:19:15.956946+00', '2025-06-25T20:55:00', '2025-06-25T20:56:00', '2025-06-25T21:19:00'),
	('fbbbb5ff-1012-41fb-854a-724852f88d5c', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'a183cb03-10ec-4dff-8f0d-fafbd4e98ee1', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2aaff65e-ca83-42ce-961f-802b7a0137ab', '0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'completed', '2025-06-25 03:20:53.169125+00', '2025-06-25 03:20:53.169125+00', '2025-06-25T04:19:00', '2025-06-25T04:20:00', '2025-06-25T04:43:00'),
	('d3ed700c-cac8-437f-abff-614ffcc3672a', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '7babbb12-15f9-4483-8b05-61220ed37167', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 03:22:16.118849+00', '2025-06-25 03:22:16.118849+00', '2025-06-25T21:21:00', '2025-06-25T21:22:00', '2025-06-25T21:37:00'),
	('6331649d-17cb-43f8-8927-09e51c3e2fb7', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '14446938-25cd-4655-ad84-dbb7db871f28', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '81c30d93-8712-405c-ac5e-509d48fd9af9', '0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'completed', '2025-06-25 03:22:44.777107+00', '2025-06-25 03:22:44.777107+00', '2025-06-25T04:22:00', '2025-06-25T04:23:00', '2025-06-25T04:51:00'),
	('75a3f096-30d6-4434-935b-6664f66bac7c', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '9dae2f86-2058-4c9c-a428-76f5648553d3', 'completed', '2025-06-25 03:23:06.773172+00', '2025-06-25 03:23:22.411135+00', '22:07', '22:08', '22:35'),
	('06ac8094-0ebf-4453-9ce3-f90bb98bd6cc', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'completed', '2025-06-25 03:23:46.737997+00', '2025-06-25 03:23:46.737997+00', '2025-06-25T04:23:00', '2025-06-25T04:24:00', '2025-06-25T04:50:00'),
	('027ac57b-f613-4fd6-8f49-dbbfe75ce0b1', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-25 03:25:52.702353+00', '2025-06-25 03:25:52.702353+00', '2025-06-25T04:25:00', '2025-06-25T04:26:00', '2025-06-25T04:40:00'),
	('8820eabe-0a51-4b05-a492-2303d98040b7', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '4430a59f-4d77-4b74-9a3c-3f2430620842', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-25 03:26:16.00255+00', '2025-06-25 03:26:16.00255+00', '2025-06-25T04:25:00', '2025-06-25T04:26:00', '2025-06-25T04:55:00'),
	('80dee8b7-a517-4517-ae63-7764cd3692dc', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '68e8e006-79dc-4d5f-aed0-20755d53403b', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '81c30d93-8712-405c-ac5e-509d48fd9af9', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-25 03:27:06.996767+00', '2025-06-25 03:27:06.996767+00', '2025-06-25T23:26:00', '2025-06-25T23:27:00', '2025-06-25T23:51:00'),
	('a8c34042-3778-4fd5-88cc-c6a4fe8fbd79', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'a59c446d-7263-4733-93ce-5823448a5fde', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '167c7358-aa39-498e-b0b0-bda652b27401', '167c7358-aa39-498e-b0b0-bda652b27401', 'completed', '2025-06-25 03:27:41.955205+00', '2025-06-25 03:27:41.955205+00', '2025-06-25T04:27:00', '2025-06-25T04:28:00', '2025-06-25T04:42:00'),
	('d71b2bc2-dd46-4c2e-bad6-290d91df33c2', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', 'a189c856-581e-4d86-9dc2-de6995be4a3a', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'completed', '2025-06-25 03:28:40.262517+00', '2025-06-25 03:28:40.262517+00', '2025-06-25T23:32:00', '2025-06-25T23:33:00', '2025-06-25T23:56:00'),
	('bdf41388-9668-4d93-b401-ec8f5d3d9af4', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'a183cb03-10ec-4dff-8f0d-fafbd4e98ee1', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'completed', '2025-06-25 03:29:38.905526+00', '2025-06-25 03:29:38.905526+00', '2025-06-25T23:28:00', '2025-06-25T23:29:00', '2025-06-25T23:43:00'),
	('377dd7eb-d103-4a06-b626-307ca2b5de72', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '68e8e006-79dc-4d5f-aed0-20755d53403b', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-25 03:30:24.863806+00', '2025-06-25 03:30:24.863806+00', '2025-06-25T00:29:00', '2025-06-25T00:30:00', '2025-06-25T00:59:00'),
	('1c475f8a-0f3a-400b-a737-573eed5be7c1', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'ee6c4e53-bcfa-4271-b0d5-dc61a5d0427c', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '02c59898-fa58-4b51-b446-7f68dfa1bb9e', 'completed', '2025-06-25 03:30:59.215594+00', '2025-06-25 03:30:59.215594+00', '2025-06-25T00:30:00', '2025-06-25T00:31:00', '2025-06-25T01:00:00'),
	('732a3e28-5372-4974-be7a-7042f18924f8', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '14446938-25cd-4655-ad84-dbb7db871f28', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-06-25 03:31:30.821752+00', '2025-06-25 03:31:30.821752+00', '2025-06-25T04:31:00', '2025-06-25T04:32:00', '2025-06-25T04:55:00'),
	('cd16bfcb-3342-495b-a26a-816e8a0fc027', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '14446938-25cd-4655-ad84-dbb7db871f28', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '831035d1-93e9-4683-af25-b40c2332b2fe', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'completed', '2025-06-25 03:32:10.165722+00', '2025-06-25 03:32:10.165722+00', '2025-06-25T01:31:00', '2025-06-25T01:32:00', '2025-06-25T01:53:00'),
	('388c4992-b4d8-46fc-9ed8-a0a35165427f', 'cc307153-0727-4d65-a47f-c8c3d007e1af', '68e8e006-79dc-4d5f-aed0-20755d53403b', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '81c30d93-8712-405c-ac5e-509d48fd9af9', '0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'completed', '2025-06-25 03:32:45.762822+00', '2025-06-25 03:32:45.762822+00', '2025-06-25T01:37:00', '2025-06-25T01:38:00', '2025-06-25T01:57:00'),
	('1c4a92c3-aee7-48a5-8ede-b57c394b9cdb', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'a183cb03-10ec-4dff-8f0d-fafbd4e98ee1', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', 'completed', '2025-06-25 03:33:45.090074+00', '2025-06-25 03:33:45.090074+00', '2025-06-25T04:32:00', '2025-06-25T04:33:00', '2025-06-25T05:01:00'),
	('002db2cf-8a62-4d05-b8c4-8388a62b4772', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4b49d53b-2473-4cc9-9b08-221a6548a93d', 'fa9e4d42-8282-42f8-bfd4-87691e20c7ed', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 03:34:18.599667+00', '2025-06-25 03:34:18.599667+00', '2025-06-25T04:33:00', '2025-06-25T04:34:00', '2025-06-25T04:55:00'),
	('61fa5a94-55af-4e4a-b2af-1a1e597e57d4', 'cc307153-0727-4d65-a47f-c8c3d007e1af', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 03:34:35.882016+00', '2025-06-25 03:34:35.882016+00', '2025-06-25T04:34:00', '2025-06-25T04:35:00', '2025-06-25T04:59:00'),
	('12bec645-5790-4a63-b059-1f2ae69b4ece', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '02c59898-fa58-4b51-b446-7f68dfa1bb9e', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 19:24:06.326764+00', '2025-06-25 19:24:06.326764+00', '2025-06-25T20:23:00', '2025-06-25T20:24:00', '2025-06-25T20:52:00'),
	('d911d681-536c-41f4-b551-464039e53027', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', 'c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-06-25 19:30:06.311222+00', '2025-06-25 19:33:48.526887+00', '20:29', '20:30', '20:48'),
	('8e08e624-cdd7-475e-af7e-9d9c800fde79', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '1aaab277-ecf2-40dd-a764-eaaf8af7615b', '4430a59f-4d77-4b74-9a3c-3f2430620842', '0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'completed', '2025-06-25 19:33:26.710492+00', '2025-06-25 19:34:33.141753+00', '20:33', '20:34', '21:00'),
	('8446416c-7638-4296-9e88-2f76ece4007c', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-06-25 19:58:14.374987+00', '2025-06-25 19:58:52.744047+00', '20:57', '20:58', '21:16'),
	('f52d1cdb-cc3c-4100-aae6-22e1a6869c62', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '75d9a7db-2806-4bb1-aec6-7131859401f7', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '90aad46b-f52f-4c04-9e84-f38d82ba7387', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'completed', '2025-06-25 20:20:05.262253+00', '2025-06-25 20:22:33.580992+00', '21:19', '21:20', '21:42'),
	('25baf9d2-eeea-441b-9976-bbd16c173954', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'completed', '2025-06-25 21:59:33.27756+00', '2025-06-25 21:59:33.27756+00', '2025-06-25T22:57:00', '2025-06-25T22:58:00', '2025-06-25T23:19:00'),
	('02e90648-77a3-44c6-af6b-dda057201b1d', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'completed', '2025-06-25 21:59:52.165387+00', '2025-06-25 21:59:52.165387+00', '2025-06-25T22:59:00', '2025-06-25T23:00:00', '2025-06-25T23:24:00'),
	('c1363a82-8b96-4adb-86bf-1f21ba652ba6', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'completed', '2025-06-25 22:00:20.817158+00', '2025-06-25 22:00:20.817158+00', '2025-06-25T22:59:00', '2025-06-25T23:00:00', '2025-06-25T23:22:00'),
	('1a13ad21-5ce1-418b-9da6-41ae3022499a', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '5bfb19a8-f295-4e17-b63d-01166fd22acf', 'ccb6bf8f-275c-4d24-8907-09b97cbe0eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-25 22:01:15.061802+00', '2025-06-25 22:01:15.061802+00', '2025-06-25T23:00:00', '2025-06-25T23:01:00', '2025-06-25T23:25:00'),
	('02efb73b-8a2d-4dc3-98d9-e1081160821f', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '1ae5c936-b74c-453e-a614-42b983416e40', 'completed', '2025-06-25 22:01:39.328646+00', '2025-06-25 22:01:39.328646+00', '2025-06-25T23:01:00', '2025-06-25T23:02:00', '2025-06-25T23:23:00'),
	('ec19bde0-7400-4854-8dd5-a5498f9da622', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'be835d6f-62c6-48bf-ae5f-5257e097349b', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', '99d8db21-2c14-4f8f-8e54-54fc81004997', 'completed', '2025-06-25 20:18:48.455524+00', '2025-06-25 22:06:00.992585+00', '2025-06-25T21:17:00', '2025-06-25T21:18:00', '2025-06-25T21:42:00'),
	('a603bcdd-f88f-4ae6-821c-22da732c6525', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '831035d1-93e9-4683-af25-b40c2332b2fe', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', 'completed', '2025-06-26 00:04:51.749198+00', '2025-06-26 00:04:51.749198+00', '2025-06-26T01:04:00', '2025-06-26T01:05:00', '2025-06-26T01:33:00'),
	('5d567644-4db9-4156-8b4d-aed5b9dfb6bf', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '5bfb19a8-f295-4e17-b63d-01166fd22acf', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 00:05:17.313555+00', '2025-06-26 00:05:17.313555+00', '2025-06-26T01:04:00', '2025-06-26T01:05:00', '2025-06-26T01:32:00'),
	('04eb17e5-cc08-4ce2-82d5-25edc7914f79', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'b02bb9e1-d3a1-4383-8275-886ebdf6bc86', NULL, '90aad46b-f52f-4c04-9e84-f38d82ba7387', 'c24a3784-6a06-469f-a764-49621f2d88d3', 'completed', '2025-06-26 00:05:56.255266+00', '2025-06-26 00:05:56.255266+00', '2025-06-26T01:05:00', '2025-06-26T01:06:00', '2025-06-26T01:27:00'),
	('723d910d-e0d2-4c47-8710-6a8f34ff859d', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '1831f136-80c5-4b85-9eff-b28610808802', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 01:27:02.633775+00', '2025-06-26 01:27:02.633775+00', '2025-06-26T02:26:00', '2025-06-26T02:27:00', '2025-06-26T02:51:00'),
	('5ecc9ed9-7aa3-40ad-b709-ed4939464774', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-06-26 01:27:33.239934+00', '2025-06-26 01:27:33.239934+00', '2025-06-26T02:27:00', '2025-06-26T02:28:00', '2025-06-26T02:46:00'),
	('f371ad79-3460-4504-8060-f329b889ab47', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 01:27:52.401148+00', '2025-06-26 01:27:52.401148+00', '2025-06-26T02:27:00', '2025-06-26T02:28:00', '2025-06-26T02:50:00'),
	('b88df3b7-b0dd-4c15-a84e-5be4d8ccef9a', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '1f1e61c3-848c-441c-8b89-8a85e16285df', '4430a59f-4d77-4b74-9a3c-3f2430620842', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'completed', '2025-06-26 01:28:19.554484+00', '2025-06-26 01:28:19.554484+00', '2025-06-26T02:27:00', '2025-06-26T02:28:00', '2025-06-26T02:48:00'),
	('95e8c161-2b53-4de2-85ff-15bb564ae18e', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', '81c30d93-8712-405c-ac5e-509d48fd9af9', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-26 01:28:50.812115+00', '2025-06-26 01:28:50.812115+00', '2025-06-26T02:28:00', '2025-06-26T02:29:00', '2025-06-26T02:53:00'),
	('85c2afb3-b689-48c6-8ded-0a497651e711', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 01:29:10.325224+00', '2025-06-26 01:29:10.325224+00', '2025-06-26T02:28:00', '2025-06-26T02:29:00', '2025-06-26T02:47:00'),
	('45b3cf9b-4336-493e-b225-6a0df5457f0b', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'completed', '2025-06-26 04:11:54.067264+00', '2025-06-26 04:11:54.067264+00', '2025-06-26T05:11:00', '2025-06-26T05:12:00', '2025-06-26T05:37:00'),
	('91ad9d8b-3227-4bf8-8cc9-1974925733f3', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '1f1e61c3-848c-441c-8b89-8a85e16285df', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 04:12:32.798284+00', '2025-06-26 04:12:32.798284+00', '2025-06-26T05:12:00', '2025-06-26T05:13:00', '2025-06-26T05:27:00'),
	('377be222-ddee-4afb-bdaf-f8622f8d898e', '9ecdca87-4206-416b-9b84-f0b83cae1fad', '68e8e006-79dc-4d5f-aed0-20755d53403b', '1f1e61c3-848c-441c-8b89-8a85e16285df', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'a189c856-581e-4d86-9dc2-de6995be4a3a', 'completed', '2025-06-26 04:32:24.560534+00', '2025-06-26 04:32:24.560534+00', '2025-06-26T05:32:00', '2025-06-26T05:33:00', '2025-06-26T05:56:00'),
	('d08d76f5-b6fc-421a-921e-ed220c253339', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 05:10:20.32056+00', '2025-06-26 05:10:20.32056+00', '2025-06-26T06:09:00', '2025-06-26T06:10:00', '2025-06-26T06:28:00'),
	('c69ebcf0-02e3-423d-bfc7-1b36bdaac2fd', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'e6068d5d-4bc5-4358-8bae-ed23759dc733', '5bfb19a8-f295-4e17-b63d-01166fd22acf', 'd213240b-3564-467a-9c2e-465bf4affe6a', '0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', 'completed', '2025-06-26 05:54:59.27778+00', '2025-06-26 05:54:59.27778+00', '2025-06-26T06:54:00', '2025-06-26T06:55:00', '2025-06-26T07:11:00'),
	('c886384b-f6ea-4dfe-b4aa-5aaf9a7516cc', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '0ef2ced8-b3f0-4e8d-a468-1b65b6b360f1', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 05:55:27.288839+00', '2025-06-26 05:55:27.288839+00', '2025-06-26T06:55:00', '2025-06-26T06:56:00', '2025-06-26T07:19:00'),
	('6604edab-42e2-415e-8cae-40c2c8b44d80', '9ecdca87-4206-416b-9b84-f0b83cae1fad', 'b8fed973-ab36-4d31-801a-7ebbde95413a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', 'completed', '2025-06-26 05:55:53.165088+00', '2025-06-26 05:55:53.165088+00', '2025-06-26T06:55:00', '2025-06-26T06:56:00', '2025-06-26T07:23:00'),
	('93414e4c-d5aa-4817-9917-b8ae45f908dd', '79dddcc3-f55f-495c-882c-2723d518248a', 'be835d6f-62c6-48bf-ae5f-5257e097349b', '4b49d53b-2473-4cc9-9b08-221a6548a93d', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', '99d8db21-2c14-4f8f-8e54-54fc81004997', 'completed', '2025-06-26 22:15:03.290579+00', '2025-06-26 22:15:03.290579+00', '2025-06-26T20:01:00', '2025-06-26T20:02:00', '2025-06-26T20:35:00'),
	('a3aa27cb-d258-4d7d-b3f4-7b2ec92387b5', '79dddcc3-f55f-495c-882c-2723d518248a', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '4430a59f-4d77-4b74-9a3c-3f2430620842', '0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'completed', '2025-06-26 22:15:24.628862+00', '2025-06-26 22:15:24.628862+00', '2025-06-26T23:15:00', '2025-06-26T23:16:00', '2025-06-26T23:45:00'),
	('4a9783a2-95e5-42fb-a7ea-a84c2c18ca9a', '79dddcc3-f55f-495c-882c-2723d518248a', '68e8e006-79dc-4d5f-aed0-20755d53403b', '5bfb19a8-f295-4e17-b63d-01166fd22acf', 'c487a171-dafb-430c-9ef9-b7f8964d7fa6', '1ae5c936-b74c-453e-a614-42b983416e40', 'completed', '2025-06-26 22:16:13.226396+00', '2025-06-26 22:16:13.226396+00', '2025-06-26T23:15:00', '2025-06-26T23:16:00', '2025-06-26T23:44:00'),
	('fcdf3308-eb67-47b0-a3dc-902d08431e63', '79dddcc3-f55f-495c-882c-2723d518248a', '68e8e006-79dc-4d5f-aed0-20755d53403b', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '81c30d93-8712-405c-ac5e-509d48fd9af9', '0c84847e-4ec6-4464-9a5c-2a6833604ce0', 'completed', '2025-06-26 22:16:42.25044+00', '2025-06-26 22:16:42.25044+00', '2025-06-26T23:16:00', '2025-06-26T23:17:00', '2025-06-26T23:44:00'),
	('0c7a041c-21f7-483a-a861-c483b2ddcb8b', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'f47ac10b-58cc-4372-a567-0e02b2c3d483', 'completed', '2025-06-26 22:17:05.672473+00', '2025-06-26 22:17:05.672473+00', '2025-06-26T23:16:00', '2025-06-26T23:17:00', '2025-06-26T23:42:00'),
	('a584a275-56a6-42ca-aa9b-f9fac1dd97a8', '79dddcc3-f55f-495c-882c-2723d518248a', 'b8fed973-ab36-4d31-801a-7ebbde95413a', '1f1e61c3-848c-441c-8b89-8a85e16285df', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', '02c59898-fa58-4b51-b446-7f68dfa1bb9e', 'completed', '2025-06-26 22:17:57.219353+00', '2025-06-26 22:17:57.219353+00', '2025-06-26T23:17:00', '2025-06-26T23:18:00', '2025-06-26T23:34:00'),
	('07171ba3-58be-472b-946d-16d6a5c802fb', '79dddcc3-f55f-495c-882c-2723d518248a', '68e8e006-79dc-4d5f-aed0-20755d53403b', '4b49d53b-2473-4cc9-9b08-221a6548a93d', 'a189c856-581e-4d86-9dc2-de6995be4a3a', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'completed', '2025-06-26 22:18:44.586596+00', '2025-06-26 22:18:44.586596+00', '2025-06-26T23:17:00', '2025-06-26T23:18:00', '2025-06-26T23:37:00'),
	('c68b54c9-048e-42ce-84b8-5590a634a180', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', '02c59898-fa58-4b51-b446-7f68dfa1bb9e', 'f47ac10b-58cc-4372-a567-0e02b2c3d484', 'completed', '2025-06-26 22:19:19.405036+00', '2025-06-26 22:19:19.405036+00', '2025-06-26T23:18:00', '2025-06-26T23:19:00', '2025-06-26T23:38:00'),
	('4ac43f4d-753a-46bc-bb61-69744af404e0', '79dddcc3-f55f-495c-882c-2723d518248a', 'be835d6f-62c6-48bf-ae5f-5257e097349b', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '3aa17398-7823-45ae-b76c-9b30d8509ce1', '99d8db21-2c14-4f8f-8e54-54fc81004997', 'completed', '2025-06-26 22:20:02.571322+00', '2025-06-26 22:20:02.571322+00', '2025-06-26T23:19:00', '2025-06-26T23:20:00', '2025-06-26T23:38:00'),
	('46a4a7c5-e97e-4def-a2e1-b0f406b418c4', '79dddcc3-f55f-495c-882c-2723d518248a', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'fa9e4d42-8282-42f8-bfd4-87691e20c7ed', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-26 22:20:27.451124+00', '2025-06-26 22:20:27.451124+00', '2025-06-26T23:20:00', '2025-06-26T23:21:00', '2025-06-26T23:41:00'),
	('3c942f58-60dd-41d5-b427-be8962ede16f', '79dddcc3-f55f-495c-882c-2723d518248a', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '1f1e61c3-848c-441c-8b89-8a85e16285df', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'completed', '2025-06-26 22:31:36.624295+00', '2025-06-26 22:31:36.624295+00', '2025-06-26T23:31:00', '2025-06-26T23:32:00', '2025-06-26T23:48:00'),
	('28cd9c92-8979-415a-ac5b-e576fe1c3144', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '81c30d93-8712-405c-ac5e-509d48fd9af9', '8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'completed', '2025-06-26 22:33:34.115555+00', '2025-06-26 22:33:34.115555+00', '2025-06-26T23:31:00', '2025-06-26T23:32:00', '2025-06-26T23:52:00'),
	('ff16adc4-1890-43f2-9729-b84d406d55c0', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '81c30d93-8712-405c-ac5e-509d48fd9af9', '8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'completed', '2025-06-26 22:33:57.143078+00', '2025-06-26 22:33:57.143078+00', '2025-06-26T23:33:00', '2025-06-26T23:34:00', '2025-06-26T23:49:00'),
	('b6f3b0f4-c80d-44c2-8006-62b10abc3041', '79dddcc3-f55f-495c-882c-2723d518248a', '68e8e006-79dc-4d5f-aed0-20755d53403b', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '81c30d93-8712-405c-ac5e-509d48fd9af9', '8a02eaa0-61c8-4c3c-846a-d723e27cd408', 'completed', '2025-06-26 22:34:20.609869+00', '2025-06-26 22:34:20.609869+00', '2025-06-26T23:34:00', '2025-06-26T23:35:00', '2025-06-26T23:49:00'),
	('d7f9b47a-723f-4eb8-ae17-ea6a829ee77f', '79dddcc3-f55f-495c-882c-2723d518248a', 'e5e84800-eb11-4889-bb97-39ea75ef5190', '1f1e61c3-848c-441c-8b89-8a85e16285df', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'completed', '2025-06-26 22:34:52.9947+00', '2025-06-26 22:34:52.9947+00', '2025-06-26T23:34:00', '2025-06-26T23:35:00', '2025-06-26T23:57:00'),
	('c7369f1a-829c-4665-887b-ffe5c46cac5c', '79dddcc3-f55f-495c-882c-2723d518248a', '68e8e006-79dc-4d5f-aed0-20755d53403b', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'a189c856-581e-4d86-9dc2-de6995be4a3a', 'completed', '2025-06-26 23:01:46.404554+00', '2025-06-26 23:01:46.404554+00', '2025-06-26T00:01:00', '2025-06-26T00:02:00', '2025-06-26T00:28:00'),
	('fd8f0421-24cf-4d44-8266-47d78d3c7414', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', '81c30d93-8712-405c-ac5e-509d48fd9af9', '3aa17398-7823-45ae-b76c-9b30d8509ce1', 'completed', '2025-06-26 23:02:11.406314+00', '2025-06-26 23:02:11.406314+00', '2025-06-26T00:01:00', '2025-06-26T00:02:00', '2025-06-26T00:19:00'),
	('87f87b9e-2eee-4b52-acba-4877e37f91cb', '79dddcc3-f55f-495c-882c-2723d518248a', 'ddcc2518-2bf4-4b6e-a1e9-c38c47a5eb01', '1f1e61c3-848c-441c-8b89-8a85e16285df', '9056ee14-242b-4208-a87d-fc59d24d442c', '02c59898-fa58-4b51-b446-7f68dfa1bb9e', 'completed', '2025-06-26 23:05:17.898863+00', '2025-06-26 23:05:17.898863+00', '2025-06-26T00:05:00', '2025-06-26T00:06:00', '2025-06-26T00:27:00'),
	('e8731066-d7a7-4d33-8193-5444e085f1a3', '79dddcc3-f55f-495c-882c-2723d518248a', '75d9a7db-2806-4bb1-aec6-7131859401f7', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', '90aad46b-f52f-4c04-9e84-f38d82ba7387', '0a2faff1-cb45-4342-ab0a-ec6fac6649c9', 'completed', '2025-06-26 23:06:10.393385+00', '2025-06-26 23:06:10.393385+00', '2025-06-26T00:05:00', '2025-06-26T00:06:00', '2025-06-26T00:25:00'),
	('13b3f340-ae66-44a9-88c6-5f2f5951ff50', '79dddcc3-f55f-495c-882c-2723d518248a', 'ee6c4e53-bcfa-4271-b0d5-dc61a5d0427c', '4ee5cc9a-fa83-4455-8df9-a6c620570a17', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', 'c24a3784-6a06-469f-a764-49621f2d88d3', 'completed', '2025-06-27 00:47:55.484873+00', '2025-06-27 00:47:55.484873+00', '2025-06-27T01:47:00', '2025-06-27T01:48:00', '2025-06-27T02:06:00'),
	('a5b4f22a-a376-4668-8922-7384de896eec', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '81c30d93-8712-405c-ac5e-509d48fd9af9', '9547f487-ef9c-4c1a-8bf9-9e423e32489d', 'completed', '2025-06-27 00:48:42.912512+00', '2025-06-27 00:48:42.912512+00', '2025-06-27T01:47:00', '2025-06-27T01:48:00', '2025-06-27T02:07:00'),
	('30c59f75-8c58-4c74-8bc0-6102f7867f41', '79dddcc3-f55f-495c-882c-2723d518248a', '496c3b93-bc9c-4ea3-b022-aa2843d166e0', '5bfb19a8-f295-4e17-b63d-01166fd22acf', '60c6f384-09d7-4ec8-bc90-b72fe1d82af9', NULL, 'completed', '2025-06-27 00:49:16.645475+00', '2025-06-27 00:49:16.645475+00', '2025-06-27T01:48:00', '2025-06-27T01:49:00', '2025-06-27T02:16:00'),
	('eb1a21b1-0cd6-4d75-ade9-4fb5364cf78a', '79dddcc3-f55f-495c-882c-2723d518248a', '8589b36d-7d7e-4cf9-9956-34667f2f4069', '1f1e61c3-848c-441c-8b89-8a85e16285df', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', '02c59898-fa58-4b51-b446-7f68dfa1bb9e', 'completed', '2025-06-27 01:21:12.192516+00', '2025-06-27 01:26:34.404371+00', '02:20', '02:21', '02:37'),
	('4f580f3b-3efa-4e57-8224-fa66cadb2415', '79dddcc3-f55f-495c-882c-2723d518248a', '5c0c9e25-ae34-4872-8696-4c4ce6e76112', '4b49d53b-2473-4cc9-9b08-221a6548a93d', 'fa9e4d42-8282-42f8-bfd4-87691e20c7ed', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-27 04:13:56.694683+00', '2025-06-27 04:13:56.694683+00', '2025-06-27T05:10:00', '2025-06-27T05:11:00', '2025-06-27T05:28:00'),
	('570f8e4f-477f-4afe-8d04-919a098f7e27', '79dddcc3-f55f-495c-882c-2723d518248a', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '4b49d53b-2473-4cc9-9b08-221a6548a93d', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', '1bd33204-7a54-4146-9a82-9344a1ee7b3a', 'completed', '2025-06-27 02:49:29.763147+00', '2025-06-27 04:14:42.193539+00', '03:48', '03:49', '04:14'),
	('65926f9a-507c-4031-8db4-6ba693cc44ba', '79dddcc3-f55f-495c-882c-2723d518248a', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '4b49d53b-2473-4cc9-9b08-221a6548a93d', 'fa9e4d42-8282-42f8-bfd4-87691e20c7ed', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-27 04:23:29.369569+00', '2025-06-27 04:23:29.369569+00', '2025-06-27T05:23:00', '2025-06-27T05:24:00', '2025-06-27T05:43:00'),
	('fde576dc-8fd1-4d75-be84-b067159f340b', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '81c30d93-8712-405c-ac5e-509d48fd9af9', '44f6b74d-f1a9-4097-b99a-b6f78e3f680c', 'completed', '2025-06-27 04:24:03.291489+00', '2025-06-27 04:24:03.291489+00', '2025-06-27T05:23:00', '2025-06-27T05:24:00', '2025-06-27T05:49:00'),
	('e7efc237-5203-48d5-9117-b14e6fb9505a', '79dddcc3-f55f-495c-882c-2723d518248a', '14446938-25cd-4655-ad84-dbb7db871f28', '1f1e61c3-848c-441c-8b89-8a85e16285df', '81c30d93-8712-405c-ac5e-509d48fd9af9', 'c487a171-dafb-430c-9ef9-b7f8964d7fa6', 'completed', '2025-06-27 04:24:24.835394+00', '2025-06-27 04:24:24.835394+00', '2025-06-27T05:24:00', '2025-06-27T05:25:00', '2025-06-27T05:49:00'),
	('658e9777-85a3-45fa-be2a-9e64089aad1d', '79dddcc3-f55f-495c-882c-2723d518248a', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '1f1e61c3-848c-441c-8b89-8a85e16285df', '6d2fec2e-7a59-4a30-97e9-03c9f4672eea', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-27 05:14:20.421936+00', '2025-06-27 05:14:20.421936+00', '2025-06-27T06:14:00', '2025-06-27T06:15:00', '2025-06-27T06:38:00'),
	('0a1d9c7f-dbc1-4e38-8cf6-5c7ff35a0302', '79dddcc3-f55f-495c-882c-2723d518248a', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-27 05:14:04.243156+00', '2025-06-27 05:15:39.224767+00', '06:13', '06:14', '06:39'),
	('b6c482a8-4cd6-4025-bde4-376997f298ad', '79dddcc3-f55f-495c-882c-2723d518248a', '3af07cde-49fa-48fc-b46a-4367a3850b9b', '1f1e61c3-848c-441c-8b89-8a85e16285df', 'a189c856-581e-4d86-9dc2-de6995be4a3a', 'c24a3784-6a06-469f-a764-49621f2d88d3', 'completed', '2025-06-27 06:37:41.021147+00', '2025-06-27 06:37:41.021147+00', '2025-06-27T07:36:00', '2025-06-27T07:37:00', '2025-06-27T08:05:00'),
	('15251c86-a5b0-4e61-9b1f-99399855213b', '79dddcc3-f55f-495c-882c-2723d518248a', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '8da75157-4cc6-4da6-84f5-6dee3a9fce27', '7693a4aa-75c6-4fa9-b659-321e5f8afd0d', '9056ee14-242b-4208-a87d-fc59d24d442c', 'completed', '2025-06-27 06:38:02.991805+00', '2025-06-27 06:38:02.991805+00', '2025-06-27T07:37:00', '2025-06-27T07:38:00', '2025-06-27T08:06:00');


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
	('1c92bb0d-1130-4e11-bf56-b9bfc1f6a49d', '532b14f0-042a-4ddf-bc7d-cb95ff298132', 'dc20fd05-19b3-4874-9d2a-a7c6e24c8b45', true, false, '2025-05-27 16:10:54.167911+00'),
	('c8ad9fba-bfa4-474a-b337-66d537d9f89f', 'dfe98d58-f606-46f0-afb9-363dfe9a4d3a', '2b3bbc1d-13fa-4af2-b23e-1e80c2225370', true, false, '2025-06-05 06:40:40.933013+00'),
	('1e8b9729-c13f-468e-884d-3e6ca1349a12', '496c3b93-bc9c-4ea3-b022-aa2843d166e0', '60c6f384-09d7-4ec8-bc90-b72fe1d82af9', true, false, '2025-06-15 10:11:58.279986+00'),
	('9552b960-6905-48b2-b547-7294d312a7dd', 'e20813d6-ef72-49bf-807e-20e8c0f2beed', '465893b5-6ab8-4776-bdbd-fd3c608ab966', true, false, '2025-06-15 11:31:36.62903+00'),
	('0168fca2-d6d8-4990-890b-f0c503637458', 'b8fed973-ab36-4d31-801a-7ebbde95413a', '969a27a7-f5e5-4c23-b018-128aa2000b97', false, true, '2025-06-15 11:32:14.623283+00'),
	('a1373b6a-ca5c-43d5-8946-07bbc7bea7b4', '81e0d17c-740a-4a00-9727-81d222f96234', '969a27a7-f5e5-4c23-b018-128aa2000b97', false, true, '2025-06-15 11:32:23.939023+00'),
	('04ff8c2b-43c6-4e20-8d42-a353f2f2d6dd', 'deab62e1-ae79-4f77-ab65-0a04c1f040a1', '5739e53c-a81f-4ee7-9a71-3ffb6e906a5e', false, true, '2025-06-15 11:32:37.605472+00'),
	('473fe53d-59fd-44c3-b72b-8591a9ff4b0d', 'a59c446d-7263-4733-93ce-5823448a5fde', '99d8db21-2c14-4f8f-8e54-54fc81004997', true, true, '2025-06-15 14:21:05.635116+00'),
	('55297013-9534-4414-8336-9cf4c10aa8eb', '8058ea70-75c8-4e46-a56f-7490a48cd4f5', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', true, false, '2025-06-17 19:22:44.744193+00'),
	('608a6bee-8823-46a4-8f26-8439d2a3b849', 'a9026cd2-92b9-4a53-acc6-4cdc0acdcf99', '7ff7d76d-3fe2-4ec9-baed-39c59cfa14e7', true, false, '2025-06-17 19:22:59.130729+00'),
	('742a311f-94d4-4dac-925f-1e7f00c4492f', '93150478-e3b7-4315-bfb2-8f44a78b2f77', '4430a59f-4d77-4b74-9a3c-3f2430620842', true, false, '2025-06-17 19:23:11.503345+00'),
	('3399338b-5666-4419-a261-dd3b7b8a04da', '1f30972f-7089-432c-953d-24d9ede86e5e', '06b9e480-8192-4637-be08-07e1755dbd6f', true, false, '2025-06-17 19:24:41.947124+00'),
	('bc7e0c71-2821-4e3d-a5bb-760e14633900', '0d249150-1b05-431d-a918-926b48a804f4', '2aaff65e-ca83-42ce-961f-802b7a0137ab', true, false, '2025-06-17 19:26:00.121853+00'),
	('bf3f6838-9282-413d-b843-f89a90cb2be8', 'b02bb9e1-d3a1-4383-8275-886ebdf6bc86', '90aad46b-f52f-4c04-9e84-f38d82ba7387', true, false, '2025-06-25 20:21:48.560218+00'),
	('c121c8b5-81bc-430f-9d8b-8c53d6406696', '75d9a7db-2806-4bb1-aec6-7131859401f7', '90aad46b-f52f-4c04-9e84-f38d82ba7387', true, false, '2025-06-25 20:21:59.100817+00'),
	('6889d4b6-6b87-469a-b3bc-72a98638d66a', 'a183cb03-10ec-4dff-8f0d-fafbd4e98ee1', '90aad46b-f52f-4c04-9e84-f38d82ba7387', true, false, '2025-06-25 20:22:10.168212+00'),
	('4405346a-a92e-4b1a-9e32-cf8978558755', 'ddcc2518-2bf4-4b6e-a1e9-c38c47a5eb01', '9056ee14-242b-4208-a87d-fc59d24d442c', true, false, '2025-06-26 23:04:48.940951+00');


--
-- Data for Name: task_type_department_assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO "public"."task_type_department_assignments" ("id", "task_type_id", "department_id", "is_origin", "is_destination", "created_at") VALUES
	('ceaa8539-8fd6-4954-8c00-2f8aea4bb3a6', 'fe0d7430-0c52-4f2b-83d5-37e1e208be07', '9056ee14-242b-4208-a87d-fc59d24d442c', false, true, '2025-05-24 12:33:59.810318+00'),
	('100f3cf6-3d37-4e48-90f3-c01b7874856b', '9299c8d0-e0a2-432b-9f96-7334d1f7d276', 'bcb9ab4c-88c9-4d90-8b10-d97216de49ed', true, false, '2025-05-24 15:23:36.64394+00'),
	('d7bec80c-dbe8-499a-a2ec-d754f1ac3551', '863c44be-48bc-4c08-bec7-603761f90ac2', '06582332-0637-4d1a-b86e-876afe0bdc98', true, false, '2025-06-15 11:49:24.516565+00'),
	('a4dd110f-e4f1-4518-964c-f969a2f60bf8', 'a47856e2-f979-4dae-9444-472e548d4a96', '167c7358-aa39-498e-b0b0-bda652b27401', true, false, '2025-06-15 14:27:18.144624+00');


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
