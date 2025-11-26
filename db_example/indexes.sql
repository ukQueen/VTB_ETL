CREATE INDEX idx_course_types_required ON course_types(is_required);
CREATE INDEX idx_scholarship_types_amount ON scholarship_types(min_amount, max_amount);
CREATE INDEX idx_prof_course_professor ON professor_course_assignments(professor_id);
CREATE INDEX idx_prof_course_course ON professor_course_assignments(course_id);
CREATE INDEX idx_student_enrollments_semester ON student_course_enrollments(semester_id, enrollment_status);
CREATE INDEX idx_course_prerequisites_course ON course_prerequisites(course_id);
CREATE INDEX idx_exchange_programs_dates ON student_exchange_programs(semester_id);
CREATE INDEX idx_prof_research_professor ON professor_research_interests(professor_id);
CREATE INDEX idx_student_activities_student ON student_extracurricular_activities(student_id);
CREATE INDEX idx_resource_keywords_resource ON resource_keywords(resource_id);
CREATE INDEX idx_funding_sources_project ON project_funding_sources(project_id);
CREATE INDEX idx_grades_student_semester ON grades(student_id, semester_id);
CREATE INDEX idx_grades_course_semester ON grades(course_id, semester_id);
CREATE INDEX idx_grades_professor_date ON grades(professor_id, grade_date);
CREATE INDEX idx_schedules_classroom_time ON schedules(classroom_id, day_of_week, start_time);
CREATE INDEX idx_schedules_professor_day ON schedules(professor_id, day_of_week);
CREATE INDEX idx_students_name_email ON students(last_name, first_name, email);
CREATE INDEX idx_students_enrollment_date ON students(enrollment_date);
CREATE INDEX idx_professors_degree ON professors(academic_degree, hire_date);
CREATE INDEX idx_professors_name ON professors(last_name, first_name);
CREATE INDEX idx_courses_program_type ON courses(program_id, course_type);
CREATE INDEX idx_research_projects_department_status ON research_projects(department_id, status_code);
CREATE INDEX idx_research_projects_dates ON research_projects(start_date, end_date);
CREATE INDEX idx_scholarships_student_status ON scholarships(student_id, status);
CREATE INDEX idx_scholarships_dates ON scholarships(start_date, end_date);
CREATE INDEX idx_events_faculty_date ON university_events(faculty_id, event_date);
CREATE INDEX idx_library_resources_title ON library_resources USING gin(to_tsvector('russian', title));
CREATE INDEX idx_library_resources_author ON library_resources USING gin(to_tsvector('russian', author));
CREATE INDEX idx_courses_description ON courses USING gin(to_tsvector('russian', description));
CREATE INDEX idx_research_projects_name ON research_projects USING gin(to_tsvector('russian', name));

-- удаление индексов
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT schemaname, indexname
        FROM pg_indexes
        WHERE schemaname = 'public'
        AND indexname NOT LIKE '%_pkey'
        AND indexdef NOT LIKE 'CREATE UNIQUE%'
    )
    LOOP
        EXECUTE 'DROP INDEX ' || quote_ident(r.schemaname) || '.' || quote_ident(r.indexname);
        RAISE NOTICE 'Удален индекс: %', r.indexname;
    END LOOP;
END $$;