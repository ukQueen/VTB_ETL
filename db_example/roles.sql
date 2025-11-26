-- Создание ролей для системы университета
CREATE ROLE admin WITH LOGIN PASSWORD '1234' SUPERUSER;
CREATE ROLE professor WITH LOGIN PASSWORD '1234';
CREATE ROLE student WITH LOGIN PASSWORD '1234';
CREATE ROLE reader WITH LOGIN PASSWORD '1234';

-- Назначение привилегий
-- Администратор (полный доступ)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin;

-- Преподаватель
GRANT SELECT, INSERT, UPDATE ON
    professors, courses, grades, schedules, professor_course_assignments,
    research_projects, professor_research_interests, equipment_requests
TO professor;

GRANT SELECT ON
    students, student_groups, study_programs, departments, faculties,
    universities, semesters, classrooms, library_resources
TO professor;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO professor;

-- Студент
GRANT SELECT ON
    courses, professors, schedules, student_groups, study_programs,
    grades, scholarships, student_course_enrollments, library_resources,
    university_events, student_extracurricular_activities
TO student;

GRANT INSERT, UPDATE ON
    student_course_enrollments, student_extracurricular_activities
TO student;

GRANT SELECT, INSERT, UPDATE ON students TO student;

-- Только чтение
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;