import psycopg2
from faker import Faker
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
import random
from tqdm import tqdm
import sys
from typing import List, Dict, Any


class DatabaseFiller:
    def __init__(self, db_params):
        self.conn = psycopg2.connect(**db_params)
        self.cur = self.conn.cursor()
        self.fake = Faker('ru_RU')
        self.fake_en = Faker('en_US')

    def execute_batch(self, query, data, batch_size=10000):
        """Эффективная пакетная вставка с обработкой ошибок"""
        total = len(data)
        for i in tqdm(range(0, total, batch_size), desc="Inserting batch"):
            batch = data[i:i + batch_size]
            try:
                self.cur.executemany(query, batch)
                self.conn.commit()
            except Exception as e:
                print(f"Ошибка при вставке batch {i}: {e}")
                self.conn.rollback()
                # Попробуем вставить по одному чтобы найти проблемную запись
                for j, record in enumerate(batch):
                    try:
                        self.cur.execute(query, record)
                        self.conn.commit()
                    except Exception as e2:
                        print(f"Ошибка в записи {j}: {record}, ошибка: {e2}")
                        self.conn.rollback()
                        continue


    def fill_dictionaries(self):
        """Заполнение словарей"""
        print("Заполнение словарей...")

        # Типы академических степеней
        degrees = [
            ('BSC', 'Бакалавр', 'Бакалавр наук', 1),
            ('MSC', 'Магистр', 'Магистр наук', 2),
            ('PHD', 'Кандидат наук', 'Кандидат наук', 3),
            ('DOC', 'Доктор наук', 'Доктор наук', 4),
            ('PROF', 'Профессор', 'Профессор', 5)
        ]
        self.cur.executemany(
            "INSERT INTO academic_degree_types VALUES (%s, %s, %s, %s)",
            degrees
        )

        # Типы курсов
        course_types = [
            ('LEC', 'Лекция', True, '[1,4]'),
            ('LAB', 'Лабораторная', True, '[1,3]'),
            ('SEM', 'Семинар', False, '[1,2]'),
            ('PRJ', 'Проект', False, '[2,6]'),
            ('PRC', 'Практика', True, '[2,4]')
        ]
        self.cur.executemany(
            "INSERT INTO course_types VALUES (%s, %s, %s, %s)",
            course_types
        )

        # Страны
        countries = [
            ('RU', 'Россия', 'Europe'),
            ('US', 'США', 'North America'),
            ('DE', 'Германия', 'Europe'),
            ('CN', 'Китай', 'Asia'),
            ('FR', 'Франция', 'Europe'),
            ('GB', 'Великобритания', 'Europe'),
            ('JP', 'Япония', 'Asia'),
            ('KR', 'Корея', 'Asia')
        ]
        self.cur.executemany(
            "INSERT INTO countries VALUES (%s, %s, %s)",
            countries
        )

        # Типы событий
        event_types = [
            ('CONF', 'Конференция', 'Научный'),
            ('SEMIN', 'Семинар', 'Образовательный'),
            ('SPORT', 'Спортивное', 'Спорт'),
            ('CULT', 'Культурное', 'Культура'),
            ('MEET', 'Встреча', 'Административный')
        ]
        self.cur.executemany(
            "INSERT INTO event_types VALUES (%s, %s, %s)",
            event_types
        )

        # Типы стипендий
        scholarship_types = [
            ('ACAD', 'Академическая', 5000, 15000, 'Высокая успеваемость'),
            ('SOC', 'Социальная', 3000, 8000, 'Социальные критерии'),
            ('RES', 'Научная', 8000, 20000, 'Научные достижения'),
            ('SPORT', 'Спортивная', 4000, 12000, 'Спортивные достижения')
        ]
        self.cur.executemany(
            "INSERT INTO scholarship_types VALUES (%s, %s, %s, %s, %s)",
            scholarship_types
        )

        # Статусы проектов
        project_statuses = [
            ('PLAN', 'Планирование', 'Проект в стадии планирования', True),
            ('ACTIVE', 'Активный', 'Проект выполняется', True),
            ('COMPL', 'Завершен', 'Проект завершен', False),
            ('SUSP', 'Приостановлен', 'Проект приостановлен', False)
        ]
        self.cur.executemany(
            "INSERT INTO project_statuses VALUES (%s, %s, %s, %s)",
            project_statuses
        )

        # Типы оборудования
        equipment_types = [
            ('COMP', 'Компьютеры', 'IT', 50000),
            ('LAB', 'Лабораторное', 'Наука', 150000),
            ('OFF', 'Офисное', 'Администрация', 20000),
            ('MED', 'Медицинское', 'Медицина', 300000)
        ]
        self.cur.executemany(
            "INSERT INTO equipment_types VALUES (%s, %s, %s, %s)",
            equipment_types
        )

        # Дни недели
        week_days = [
            (1, 'Понедельник', False),
            (2, 'Вторник', False),
            (3, 'Среда', False),
            (4, 'Четверг', False),
            (5, 'Пятница', False),
            (6, 'Суббота', True),
            (7, 'Воскресенье', True)
        ]
        self.cur.executemany(
            "INSERT INTO week_days VALUES (%s, %s, %s)",
            week_days
        )

        self.conn.commit()

    def fill_universities(self, count=5):
        """Заполнение университетов"""
        print("Заполнение университетов...")
        data = []
        for i in range(count):
            data.append((
                f"Университет {self.fake.company()}",
                self.fake.address(),
                self.fake.date_between(start_date='-50y', end_date='-10y'),
                random.choice(['I', 'II', 'III', 'IV', 'V'])
            ))

        self.execute_batch(
            "INSERT INTO universities (name, address, founded_date, accreditation_level) VALUES (%s, %s, %s, %s)",
            data
        )

    def fill_faculties(self, count_per_university=4):
        """Заполнение факультетов"""
        print("Заполнение факультетов...")
        self.cur.execute("SELECT university_id FROM universities")
        university_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        faculty_names = ['Информационных технологий', 'Экономический', 'Юридический',
                         'Медицинский', 'Инженерный', 'Гуманитарный', 'Естественных наук']

        for uni_id in university_ids:
            for i in range(count_per_university):
                data.append((
                    uni_id,
                    f"Факультет {random.choice(faculty_names)}",
                    self.fake.name(),
                    f"{random.randint(1, 10)}"
                ))

        self.execute_batch(
            "INSERT INTO faculties (university_id, name, dean_name, building_number) VALUES (%s, %s, %s, %s)",
            data
        )

    def fill_departments(self, count_per_faculty=3):
        """Заполнение кафедр"""
        print("Заполнение кафедр...")
        self.cur.execute("SELECT faculty_id FROM faculties")
        faculty_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        department_names = ['Программирования', 'Математики', 'Физики', 'Химии',
                            'Биологии', 'Истории', 'Философии', 'Экономики', 'Права']

        for faculty_id in faculty_ids:
            for i in range(count_per_faculty):
                data.append((
                    faculty_id,
                    f"Кафедра {random.choice(department_names)}",
                    self.fake.name(),
                    self.fake.phone_number()[:15]
                ))

        self.execute_batch(
            "INSERT INTO departments (faculty_id, name, head_name, phone) VALUES (%s, %s, %s, %s)",
            data
        )

    def fill_students(self, count=500000):
        """Заполнение студентов (~500K записей)"""
        print("Заполнение студентов...")
        data = []

        for i in tqdm(range(count), desc="Generating students"):
            data.append((
                self.fake.first_name(),
                self.fake.last_name(),
                self.fake.date_of_birth(minimum_age=17, maximum_age=25),
                f"student_{i}@university.edu",
                self.fake.phone_number()[:15],
                self.fake.date_between(start_date='-5y', end_date='today')
            ))

            if len(data) >= 10000:
                self.execute_batch(
                    "INSERT INTO students (first_name, last_name, birth_date, email, phone, enrollment_date) VALUES (%s, %s, %s, %s, %s, %s)",
                    data
                )
                data = []

        if data:
            self.execute_batch(
                "INSERT INTO students (first_name, last_name, birth_date, email, phone, enrollment_date) VALUES (%s, %s, %s, %s, %s, %s)",
                data
            )

    def fill_professors(self, count=20000):
        """Заполнение преподавателей (~20K записей)"""
        print("Заполнение преподавателей...")
        data = []

        for i in tqdm(range(count), desc="Generating professors"):
            data.append((
                self.fake.first_name(),
                self.fake.last_name(),
                random.choice(['BSC', 'MSC', 'PHD', 'DOC', 'PROF']),
                f"prof_{i}@university.edu",
                self.fake.date_between(start_date='-30y', end_date='-1y'),
                f"{random.randint(100, 500)}-{random.randint(1, 50)}"
            ))

        self.execute_batch(
            "INSERT INTO professors (first_name, last_name, academic_degree, email, hire_date, office_number) VALUES (%s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_study_programs(self, count_per_department=2):
        """Заполнение учебных программ"""
        print("Заполнение учебных программ...")
        self.cur.execute("SELECT department_id FROM departments")
        department_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        program_names = ['Компьютерные науки', 'Экономика', 'Юриспруденция',
                         'Медицина', 'Инженерия', 'Физика', 'Химия', 'Биология']

        for dept_id in department_ids:
            for i in range(count_per_department):
                data.append((
                    dept_id,
                    f"Программа '{random.choice(program_names)}'",
                    random.randint(4, 6),
                    random.choice(['Бакалавр', 'Магистр', 'Специалист'])
                ))

        self.execute_batch(
            "INSERT INTO study_programs (department_id, name, duration_years, degree_type) VALUES (%s, %s, %s, %s)",
            data
        )

    def fill_courses(self, count_per_program=8):
        """Заполнение курсов"""
        print("Заполнение курсов...")
        self.cur.execute("SELECT program_id FROM study_programs")
        program_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        course_names = ['Математический анализ', 'Программирование', 'Базы данных',
                        'Физика', 'Химия', 'История', 'Философия', 'Экономика']

        for prog_id in program_ids:
            for i in range(count_per_program):
                data.append((
                    prog_id,
                    f"{random.choice(course_names)} {random.randint(1, 4)}",
                    f"COURSE-{prog_id}-{i}",
                    random.choice(['LEC', 'LAB', 'SEM', 'PRJ', 'PRC']),
                    random.randint(2, 6),
                    self.fake.text(max_nb_chars=200),
                    random.choice(['Бакалавр', 'Магистр'])
                ))

        self.execute_batch(
            "INSERT INTO courses (program_id, name, course_code, course_type, credits, description, course_level) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_classrooms(self, count=1000):
        """Заполнение аудиторий"""
        print("Заполнение аудиторий...")
        data = []
        for i in range(count):
            data.append((
                random.randint(1, 10),
                f"{random.randint(1, 5)}-{random.randint(100, 500)}",
                random.randint(20, 300),
                random.choice(['Компьютеры', 'Проектор', 'Лабораторное', 'Стандартное']),
                random.choice([True, False])
            ))

        self.execute_batch(
            "INSERT INTO classrooms (building_id, room_number, capacity, equipment_type, is_laboratory) VALUES (%s, %s, %s, %s, %s)",
            data
        )

    def fill_student_groups(self, count_per_program=3):
        """Заполнение студенческих групп"""
        print("Заполнение студенческих групп...")
        self.cur.execute("SELECT program_id FROM study_programs")
        program_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT professor_id FROM professors")
        professor_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for program_id in program_ids:
            for i in range(count_per_program):
                data.append((
                    program_id,
                    f"Группа {program_id}-{i + 1}",
                    random.randint(2020, 2023),
                    random.choice(professor_ids) if professor_ids else None
                ))

        self.execute_batch(
            "INSERT INTO student_groups (program_id, name, start_year, curator_id) VALUES (%s, %s, %s, %s)",
            data
        )

    def fill_research_projects(self, count=100000):
        """Заполнение исследовательских проектов (~100K записей)"""
        print("Заполнение исследовательских проектов...")

        self.cur.execute("SELECT department_id FROM departments")
        department_ids = [row[0] for row in self.cur.fetchall()]

        data = []

        for i in tqdm(range(count), desc="Generating projects"):
            data.append((
                random.choice(department_ids),
                f"Проект '{self.fake.catch_phrase()}'",
                round(random.uniform(100000, 5000000), 2),
                self.fake.date_between(start_date='-3y', end_date='-1y'),
                self.fake.date_between(start_date='today', end_date='+2y'),
                random.choice(['PLAN', 'ACTIVE', 'COMPL', 'SUSP']),
                f"PRJ-{i:06d}"
            ))

        self.execute_batch(
            "INSERT INTO research_projects (department_id, name, budget, start_date, end_date, status_code, project_code) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_library_resources(self, count=200000):
        """Заполнение библиотечных ресурсов (~200K записей)"""
        print("Заполнение библиотечных ресурсов...")

        self.cur.execute("SELECT department_id FROM departments")
        department_ids = [row[0] for row in self.cur.fetchall()]

        data = []

        for i in tqdm(range(count), desc="Generating library resources"):
            data.append((
                f"{self.fake_en.catch_phrase()} {random.choice(['Theory', 'Practice', 'Guide', 'Manual'])}",
                self.fake_en.name(),
                random.choice(['Книга', 'Журнал', 'Статья', 'Диссертация', 'Учебник']),
                self.fake.isbn13(),
                random.randint(1, 10),
                random.choice(department_ids)
            ))

        self.execute_batch(
            "INSERT INTO library_resources (title, author, resource_type, isbn, available_copies, department_id) VALUES (%s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_international_partnerships(self, count=500):
        """Заполнение международных партнерств"""
        print("Заполнение международных партнерств...")

        self.cur.execute("SELECT university_id FROM universities")
        university_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for i in range(count):
            data.append((
                random.choice(university_ids),
                f"University of {self.fake_en.city()}",
                random.choice(['RU', 'US', 'DE', 'CN', 'FR', 'GB']),
                random.choice(['Соглашение', 'Меморандум', 'Программа обмена']),
                self.fake.date_between(start_date='-5y', end_date='-1y'),
                self.fake.date_between(start_date='today', end_date='+3y'),
                f"AGR-{i:06d}"
            ))

        self.execute_batch(
            "INSERT INTO international_partnerships (university_id, partner_university, country_code, agreement_type, start_date, end_date, agreement_number) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_professor_course_assignments(self, count_per_professor=3):
        """Заполнение назначений преподавателей на курсы"""
        print("Заполнение назначений преподавателей...")

        self.cur.execute("SELECT professor_id FROM professors")
        professor_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT course_id FROM courses")
        course_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT semester_id FROM semesters")
        semester_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for professor_id in tqdm(professor_ids, desc="Assigning professors to courses"):
            assigned_courses = random.sample(course_ids, min(count_per_professor, len(course_ids)))
            for course_id in assigned_courses:
                data.append((
                    professor_id,
                    course_id,
                    random.choice(semester_ids),
                    random.randint(2, 8),
                    random.choice([True, False])
                ))

                if len(data) >= 10000:
                    self.execute_batch(
                        "INSERT INTO professor_course_assignments (professor_id, course_id, semester_id, hours_per_week, is_primary_instructor) VALUES (%s, %s, %s, %s, %s)",
                        data
                    )
                    data = []

        if data:
            self.execute_batch(
                "INSERT INTO professor_course_assignments (professor_id, course_id, semester_id, hours_per_week, is_primary_instructor) VALUES (%s, %s, %s, %s, %s)",
                data
            )

    def fill_student_course_enrollments(self, count_per_student=8):
        """Заполнение записей на курсы (~4M записей)"""
        print("Заполнение записей на курсы...")

        self.cur.execute("SELECT student_id FROM students LIMIT 500000")
        student_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT course_id FROM courses")
        course_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT semester_id FROM semesters")
        semester_ids = [row[0] for row in self.cur.fetchall()]

        data = []

        for student_id in tqdm(student_ids, desc="Generating enrollments"):
            courses_taken = random.sample(course_ids, min(count_per_student, len(course_ids)))
            for course_id in courses_taken:
                data.append((
                    student_id,
                    course_id,
                    random.choice(semester_ids),
                    self.fake.date_between(start_date='-2y', end_date='today'),
                    random.choice(['active', 'completed', 'dropped'])
                ))

                if len(data) >= 10000:
                    self.execute_batch(
                        "INSERT INTO student_course_enrollments (student_id, course_id, semester_id, enrollment_date, enrollment_status) VALUES (%s, %s, %s, %s, %s)",
                        data
                    )
                    data = []

        if data:
            self.execute_batch(
                "INSERT INTO student_course_enrollments (student_id, course_id, semester_id, enrollment_date, enrollment_status) VALUES (%s, %s, %s, %s, %s)",
                data
            )



    def fill_grades(self, count_per_student=20):
        """Заполнение оценок (~10M записей)"""
        print("Заполнение оценок...")

        # Получаем ID студентов и курсов
        self.cur.execute("SELECT student_id FROM students LIMIT 250000")
        student_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT DISTINCT course_id, professor_id FROM professor_course_assignments LIMIT 10000")
        course_professors = [(row[0], row[1]) for row in self.cur.fetchall()]
        if not course_professors:
            print("Ошибка: нет данных в professor_course_assignments")
            return


        self.cur.execute("SELECT semester_id FROM semesters")
        semester_ids = [row[0] for row in self.cur.fetchall()]

        data = []

        for student_id in tqdm(student_ids, desc="Generating grades"):
            for _ in range(count_per_student):
                course_id, professor_id = random.choice(course_professors)
                data.append((
                    student_id,
                    course_id,
                    professor_id,
                    random.choice(semester_ids),
                    round(random.uniform(2.0, 5.0), 2),
                    self.fake.date_between(start_date='-2y', end_date='today'),
                    random.choice(['Экзамен', 'Зачет', 'Курсовая'])
                ))

                if len(data) >= 10000:
                    self.execute_batch(
                        "INSERT INTO grades (student_id, course_id, professor_id, semester_id, grade_value, grade_date, exam_type) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                        data
                    )
                    data = []

        if data:
            self.execute_batch(
                "INSERT INTO grades (student_id, course_id, professor_id, semester_id, grade_value, grade_date, exam_type) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                data
            )

    def fill_scholarships(self, count=100000):
        """Заполнение стипендий"""
        print("Заполнение стипендий...")

        self.cur.execute("SELECT student_id FROM students LIMIT 100000")
        student_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for i in range(count):
            data.append((
                random.choice(student_ids),
                random.choice(['ACAD', 'SOC', 'RES', 'SPORT']),
                round(random.uniform(3000, 20000), 2),
                self.fake.date_between(start_date='-1y', end_date='today'),
                self.fake.date_between(start_date='today', end_date='+1y'),
                self.fake.date_between(start_date='-2y', end_date='today'),
                random.choice(['active', 'completed', 'cancelled'])
            ))

        self.execute_batch(
            "INSERT INTO scholarships (student_id, type_code, amount, start_date, end_date, application_date, status) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_schedules(self, count=50000):
        """Заполнение расписания"""
        print("Заполнение расписания...")

        self.cur.execute("SELECT course_id FROM courses")
        course_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT professor_id FROM professors")
        professor_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT group_id FROM student_groups")
        group_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT classroom_id FROM classrooms")
        classroom_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for i in range(count):
            data.append((
                random.choice(course_ids),
                random.choice(professor_ids),
                random.choice(group_ids),
                random.choice(classroom_ids),
                random.randint(1, 5),  # только рабочие дни
                f"{random.randint(8, 18)}:{random.choice(['00', '30'])}:00",
                f"{random.randint(9, 19)}:{random.choice(['00', '30'])}:00",
                random.choice(['Лекция', 'Семинар', 'Лабораторная'])
            ))

        self.execute_batch(
            "INSERT INTO schedules (course_id, professor_id, group_id, classroom_id, day_of_week, start_time, end_time, schedule_type) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_equipment_requests(self, count=50000):
        """Заполнение заявок на оборудование"""
        print("Заполнение заявок на оборудование...")

        self.cur.execute("SELECT department_id FROM departments")
        department_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT professor_id FROM professors")
        professor_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for i in range(count):
            data.append((
                random.choice(department_ids),
                random.choice(professor_ids),
                f"Оборудование {self.fake.word()}",
                random.choice(['COMP', 'LAB', 'OFF', 'MED']),
                random.randint(1, 50),
                round(random.uniform(10000, 500000), 2),
                self.fake.date_between(start_date='-1y', end_date='today'),
                random.choice(['pending', 'approved', 'rejected', 'completed']),
                random.randint(1, 5)
            ))

        self.execute_batch(
            "INSERT INTO equipment_requests (department_id, professor_id, equipment_name, equipment_type, quantity, budget, request_date, status, priority) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_university_events(self, count=10000):
        """Заполнение событий университета"""
        print("Заполнение событий университета...")

        self.cur.execute("SELECT faculty_id FROM faculties")
        faculty_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for i in range(count):
            data.append((
                random.choice(faculty_ids),
                f"Событие {self.fake.word()}",
                self.fake.date_between(start_date='-1y', end_date='+1y'),
                random.choice(['CONF', 'SEMIN', 'SPORT', 'CULT', 'MEET']),
                random.randint(10, 1000),
                round(random.uniform(1000, 100000), 2),
                self.fake.address()
            ))

        self.execute_batch(
            "INSERT INTO university_events (faculty_id, name, event_date, event_type_code, participants_count, budget, location) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_student_exchange_programs(self, count=5000):
        """Заполнение программ обмена"""
        print("Заполнение программ обмена...")

        self.cur.execute("SELECT student_id FROM students LIMIT 50000")
        student_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT partnership_id FROM international_partnerships")
        partnership_ids = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT semester_id FROM semesters")
        semester_ids = [row[0] for row in self.cur.fetchall()]

        data = []
        for i in range(count):
            data.append((
                random.choice(student_ids),
                random.choice(partnership_ids),
                random.choice(semester_ids),
                f"University in {self.fake_en.city()}",
                f"Course1, Course2, Course3",
                random.randint(15, 30)
            ))

        self.execute_batch(
            "INSERT INTO student_exchange_programs (student_id, partnership_id, semester_id, destination_university, courses_taken, credits_transferred) VALUES (%s, %s, %s, %s, %s, %s)",
            data
        )

    def fill_professor_research_interests(self, count=30000):
        """Заполнение научных интересов преподавателей"""
        print("Заполнение научных интересов...")

        self.cur.execute("SELECT professor_id FROM professors")
        professor_ids = [row[0] for row in self.cur.fetchall()]

        research_fields = [
            'Искусственный интеллект', 'Машинное обучение', 'Наука о данных', 'Кибербезопасность',
            'Биоинформатика', 'Квантовые вычисления', 'Робототехника', 'Интернет вещей',
            'Большие данные', 'Облачные вычисления', 'Блокчейн', 'Компьютерное зрение',
            'Обработка естественного языка', 'Нейронные сети', 'Анализ алгоритмов',
            'Распределенные системы', 'Базы данных', 'Программная инженерия', 'Веб-технологии',
            'Мобильная разработка', 'DevOps', 'Тестирование ПО', 'Управление проектами'
        ]

        # Сначала проверим существующие записи
        self.cur.execute("SELECT professor_id, research_field FROM professor_research_interests")
        existing_combinations = set((row[0], row[1]) for row in self.cur.fetchall())

        data = []
        used_combinations = set(existing_combinations)  # Начинаем с существующих

        attempts = 0
        max_attempts = count * 5

        with tqdm(total=count, desc="Research interests") as pbar:
            while len(data) < count and attempts < max_attempts:
                professor_id = random.choice(professor_ids)
                research_field = random.choice(research_fields)
                combination = (professor_id, research_field)

                if combination not in used_combinations:
                    used_combinations.add(combination)
                    data.append((
                        professor_id,
                        research_field,
                        random.choice(['Начальный', 'Средний', 'Продвинутый', 'Эксперт']),
                        random.randint(1, 25)
                    ))
                    pbar.update(1)

                    if len(data) >= 10000:
                        self.execute_batch(
                            "INSERT INTO professor_research_interests (professor_id, research_field, expertise_level, years_of_experience) VALUES (%s, %s, %s, %s)",
                            data
                        )
                        data = []

                attempts += 1

        if data:
            self.execute_batch(
                "INSERT INTO professor_research_interests (professor_id, research_field, expertise_level, years_of_experience) VALUES (%s, %s, %s, %s)",
                data
            )

        print(f"Добавлено {len(used_combinations) - len(existing_combinations)} новых научных интересов")

    def fill_resource_keywords(self, count=100000):
        """Заполнение ключевых слов для библиотечных ресурсов"""
        print("Заполнение ключевых слов...")

        self.cur.execute("SELECT resource_id FROM library_resources")
        resource_ids = [row[0] for row in self.cur.fetchall()]

        keywords = [
            'программирование', 'алгоритмы', 'базы данных', 'искусственный интеллект',
            'машинное обучение', 'веб-разработка', 'мобильные приложения', 'кибербезопасность',
            'сети', 'операционные системы', 'анализ данных', 'статистика', 'математика',
            'физика', 'химия', 'биология', 'медицина', 'экономика', 'менеджмент', 'маркетинг',
            'финансы', 'право', 'история', 'философия', 'психология', 'социология',
            'лингвистика', 'литература', 'искусство', 'дизайн', 'архитектура', 'строительство',
            'механика', 'электроника', 'робототехника', 'биотехнологии', 'нанотехнологии',
            'экология', 'география', 'геология', 'астрономия', 'космос'
        ]

        # Существующие записи
        self.cur.execute("SELECT resource_id, keyword FROM resource_keywords")
        existing_combinations = set((row[0], row[1]) for row in self.cur.fetchall())

        data = []
        used_combinations = set(existing_combinations)
        attempts = 0
        max_attempts = count * 5

        with tqdm(total=count, desc="Resource keywords") as pbar:
            while len(data) < count and attempts < max_attempts:
                resource_id = random.choice(resource_ids)
                keyword = random.choice(keywords)
                combination = (resource_id, keyword)

                if combination not in used_combinations:
                    used_combinations.add(combination)
                    data.append((resource_id, keyword))
                    pbar.update(1)

                    if len(data) >= 10000:
                        self.execute_batch(
                            "INSERT INTO resource_keywords (resource_id, keyword) VALUES (%s, %s)",
                            data
                        )
                        data = []

                attempts += 1

        if data:
            self.execute_batch(
                "INSERT INTO resource_keywords (resource_id, keyword) VALUES (%s, %s)",
                data
            )

        print(f"Добавлено {len(used_combinations) - len(existing_combinations)} новых ключевых слов")

    def fill_course_prerequisites(self, count=5000):
        """Заполнение предварительных требований для курсов"""
        print("Заполнение предварительных требований...")

        self.cur.execute("SELECT course_id FROM courses WHERE course_level = 'Магистр'")
        advanced_courses = [row[0] for row in self.cur.fetchall()]

        self.cur.execute("SELECT course_id FROM courses WHERE course_level = 'Бакалавр'")
        basic_courses = [row[0] for row in self.cur.fetchall()]

        # Существующие записи
        self.cur.execute("SELECT course_id, required_course_id FROM course_prerequisites")
        existing_combinations = set((row[0], row[1]) for row in self.cur.fetchall())

        data = []
        used_combinations = set(existing_combinations)
        attempts = 0
        max_attempts = count * 5

        with tqdm(total=count, desc="Course prerequisites") as pbar:
            while len(data) < count and attempts < max_attempts and advanced_courses and basic_courses:
                course_id = random.choice(advanced_courses)
                required_course_id = random.choice(basic_courses)
                combination = (course_id, required_course_id)

                if combination not in used_combinations:
                    used_combinations.add(combination)
                    data.append((
                        course_id,
                        required_course_id,
                        round(random.uniform(3.0, 4.5), 2),
                        random.choice([True, False])
                    ))
                    pbar.update(1)

                    if len(data) >= 10000:
                        self.execute_batch(
                            "INSERT INTO course_prerequisites (course_id, required_course_id, min_grade, is_mandatory) VALUES (%s, %s, %s, %s)",
                            data
                        )
                        data = []

                attempts += 1

        if data:
            self.execute_batch(
                "INSERT INTO course_prerequisites (course_id, required_course_id, min_grade, is_mandatory) VALUES (%s, %s, %s, %s)",
                data
            )

        print(f"Добавлено {len(used_combinations) - len(existing_combinations)} новых пререквизитов")

    def fill_project_funding_sources(self, count=50000):
        """Заполнение источников финансирования проектов"""
        print("Заполнение источников финансирования...")

        self.cur.execute("SELECT project_id FROM research_projects")
        project_ids = [row[0] for row in self.cur.fetchall()]

        funders = [
            'Российский научный фонд', 'Министерство науки и высшего образования',
            'Российский фонд фундаментальных исследований', 'Европейский научный совет',
            'Национальный институт здоровья', 'Национальный научный фонд',
            'Фонд Сколково', 'Инновационный центр', 'Венчурные инвестиции',
            'Корпоративное финансирование', 'Международные гранты', 'Частные доноры'
        ]

        data = []
        for i in range(count):
            project_id = random.choice(project_ids)
            funder = random.choice(funders)
            grant_num = f"GRANT-{random.randint(1000, 9999)}-{random.randint(100, 999)}"
            data.append((
                project_id,
                funder,
                round(random.uniform(50000, 2000000), 2),
                random.choice(['Грант', 'Контракт', 'Пожертвование', 'Инвестиции']),
                grant_num
            ))

        self.execute_batch(
            "INSERT INTO project_funding_sources (project_id, funder_name, amount, funding_type, grant_number) VALUES (%s, %s, %s, %s, %s)",
            data
        )

    def fill_student_extracurricular(self, count=100000):
        """Заполнение внеучебной деятельности студентов"""
        print("Заполнение внеучебной деятельности...")

        self.cur.execute("SELECT student_id FROM students LIMIT 200000")
        student_ids = [row[0] for row in self.cur.fetchall()]

        activities = [
            'Спортивная секция', 'Научный кружок', 'Волонтерство', 'Студенческий совет',
            'Художественная самодеятельность', 'Технический кружок', 'Дебаты',
            'Языковой клуб', 'IT-сообщество', 'Предпринимательский клуб',
            'Экологическое движение', 'Патриотический клуб', 'Туристический клуб',
            'Фотокружок', 'Театральная студия', 'Музыкальная группа', 'Танцы',
            'Шахматный клуб', 'Киберспорт', 'Медиацентр'
        ]

        roles = [
            'Участник', 'Активный участник', 'Организатор', 'Руководитель',
            'Координатор', 'Волонтер', 'Член совета', 'Капитан команды'
        ]

        data = []
        for i in range(count):
            student_id = random.choice(student_ids)
            activity = random.choice(activities)
            start_date = self.fake.date_between(start_date='-3y', end_date='-6m')

            data.append((
                student_id,
                activity,
                random.choice(roles),
                start_date,
                self.fake.date_between(start_date=start_date, end_date='today') if random.random() > 0.3 else None,
                random.randint(2, 15)
            ))

        self.execute_batch(
            "INSERT INTO student_extracurricular_activities (student_id, activity_type, role, start_date, end_date, hours_per_week) VALUES (%s, %s, %s, %s, %s, %s)",
            data
        )


    def fill_all_data(self):
        """Основной метод заполнения всех данных"""
        try:
            # 1. Заполняем словари
            # self.fill_dictionaries()

            # 2. Заполняем основные таблицы
            # self.fill_universities()
            # self.fill_faculties()
            # self.fill_departments()
            # self.fill_study_programs()
            # self.fill_courses()

            # 3. Создаем семестры
            # semesters_data = []
            # for year in range(2018, 2024):
            #     semesters_data.append((f"Осенний {year}", f"{year}-09-01", f"{year}-12-31", False))
            #     semesters_data.append((f"Весенний {year + 1}", f"{year + 1}-01-15", f"{year + 1}-05-31", year == 2023))
            # self.cur.executemany(
            #     "INSERT INTO semesters (name, start_date, end_date, is_current) VALUES (%s, %s, %s, %s)",
            #     semesters_data
            # )
            # self.conn.commit()

            # 4. Заполняем таблицы с большим количеством данных
            # self.fill_students(500000)  # 500K студентов
            # self.fill_professors(20000)  # 20K преподавателей
            # self.fill_classrooms(1000)  # 1K аудиторий
            # self.fill_student_groups()  # группы

            # 5. Заполняем дополнительные таблицы
            # self.fill_research_projects(100000)  # 100K проектов
            # self.fill_library_resources(200000)  # 200K ресурсов

            # 6. Заполняем международные партнерства ДО обменов
            # self.fill_international_partnerships(500)

            # 7. Заполняем связи многие-ко-многим
            # self.fill_professor_course_assignments(3)  # ~60K назначений
            # self.fill_student_course_enrollments(8)  # ~4M записей
            # self.fill_grades(20)  # ~10M оценок

            # 8. Заполняем остальные связи
            # self.fill_scholarships(100000)  # 100K стипендий
            # self.fill_schedules(50000)  # 50K расписаний
            # self.fill_equipment_requests(50000)  # 50K заявок
            # self.fill_university_events(10000)  # 10K событий
            # self.fill_student_exchange_programs(5000)  # 5K обменов

            print("Заполнение оставшихся таблиц...")

            self.fill_professor_research_interests(30000)  # 30K научных интересов
            self.fill_project_funding_sources(50000)  # 50K источников финансирования
            self.fill_student_extracurricular(100000)  # 100K внеучебных активностей
            self.fill_resource_keywords(100000)  # 100K ключевых слов
            self.fill_course_prerequisites(5000)  # 5K пререквизитов

            print("Заполнение базы данных завершено!")

        except Exception as e:
            print(f"Ошибка: {e}")
            import traceback
            traceback.print_exc()
            self.conn.rollback()
        finally:
            self.cur.close()
            self.conn.close()


# Параметры подключения
DB_PARAMS = {
    'host': 'localhost',
    'database': 'vtb_etl',
    'user': 'postgres',
    'password': '12345678',
    'port': 5432
}

if __name__ == "__main__":
    print("Начало заполнения базы данных...")
    filler = DatabaseFiller(DB_PARAMS)
    filler.fill_all_data()
    print("Готово!")