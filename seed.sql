BEGIN;

INSERT INTO employee_job_title (job_title_name) VALUES
                                                    ('товаровед'), ('менеджер'), ('бухгалтер'), ('заведующий');

INSERT INTO monetary_unit (currency, country, description) VALUES
                                                               ('RUB', 'Россия', 'Российский рубль'),
                                                               ('USD', 'США', 'Доллар США'),
                                                               ('EUR', 'Еврозона', 'Евро');

INSERT INTO company_category (company_category_name)
VALUES ('Торговая фирма');

INSERT INTO company_category
(company_category_name, company_category_parent_id)
VALUES
    ('Магазин', (SELECT company_category_id FROM company_category
                 WHERE company_category_name = 'Торговая фирма')),
    ('Оптовик', (SELECT company_category_id FROM company_category
                 WHERE company_category_name = 'Торговая фирма'));

INSERT INTO group_of_items (group_name, group_description) VALUES
                                                               ('Продукты питания', 'Продовольственные товары'),
                                                               ('Бытовая химия', 'Средства для дома');

INSERT INTO group_of_items
(parental_group_id, group_name, group_description)
VALUES
    ((SELECT group_of_items_id FROM group_of_items
      WHERE group_name = 'Продукты питания'),
     'Напитки', 'Безалкогольные напитки');

INSERT INTO employee
(supervisor_id, job_title_id, tin, login, passport,
 password, full_name, birthday_date, gender, phone_number)
VALUES
    (NULL,
     (SELECT job_title_id FROM employee_job_title
      WHERE job_title_name = 'заведующий'),
     '770000000004', 'head_demo', '4500000004',
     'demo_password_4', 'Смирнова Анна Петровна',
     '1980-04-12', 'ж', '+79990000004');

INSERT INTO employee
(supervisor_id, job_title_id, tin, login, passport,
 password, full_name, birthday_date, gender, phone_number)
VALUES
    ((SELECT employee_id FROM employee WHERE login = 'head_demo'),
     (SELECT job_title_id FROM employee_job_title
      WHERE job_title_name = 'товаровед'),
     '770000000001', 'merch_demo', '4500000001',
     'demo_password_1', 'Иванов Иван Иванович',
     '1990-01-15', 'м', '+79990000001'),
    ((SELECT employee_id FROM employee WHERE login = 'head_demo'),
     (SELECT job_title_id FROM employee_job_title
      WHERE job_title_name = 'менеджер'),
     '770000000002', 'manager_demo', '4500000002',
     'demo_password_2', 'Петрова Мария Сергеевна',
     '1992-06-20', 'ж', '+79990000002'),
    ((SELECT employee_id FROM employee WHERE login = 'head_demo'),
     (SELECT job_title_id FROM employee_job_title
      WHERE job_title_name = 'бухгалтер'),
     '770000000003', 'accountant_demo', '4500000003',
     'demo_password_3', 'Сидоров Павел Олегович',
     '1988-11-03', 'м', '+79990000003');

INSERT INTO company
(company_category_id, company_name, registered_address,
 phone_number, licence_id, bank_bik)
VALUES
    ((SELECT company_category_id FROM company_category
      WHERE company_category_name = 'Магазин'),
     'ООО Север', 'Москва, улица Лесная, 10',
     '+74950000001', 'LIC-001', '044525001'),
    ((SELECT company_category_id FROM company_category
      WHERE company_category_name = 'Оптовик'),
     'ООО Восток', 'Казань, улица Центральная, 5',
     '+78430000002', 'LIC-002', '049205002'),
    ((SELECT company_category_id FROM company_category
      WHERE company_category_name = 'Магазин'),
     'ООО Резерв', 'Самара, улица Мира, 7',
     '+78460000003', 'LIC-003', '043601003');

INSERT INTO item
(item_group, item_name, certificate_id, item_quantity,
 item_id_within_group, merchandiser_id, sku, package,
 manufacturer_name)
VALUES
    ((SELECT group_of_items_id FROM group_of_items
      WHERE group_name = 'Напитки'),
     'Сок яблочный 1 л', 'CERT-001', 46, 1,
     (SELECT employee_id FROM employee WHERE login = 'merch_demo'),
     '460000000001', 'Пакет 1 л', 'ООО Сады'),
    ((SELECT group_of_items_id FROM group_of_items
      WHERE group_name = 'Напитки'),
     'Вода питьевая 1 л', 'CERT-002', 35, 2,
     (SELECT employee_id FROM employee WHERE login = 'merch_demo'),
     '460000000002', 'Бутылка 1 л', 'ООО Источник'),
    ((SELECT group_of_items_id FROM group_of_items
      WHERE group_name = 'Бытовая химия'),
     'Средство для посуды 500 мл', 'CERT-003', 30, 1,
     (SELECT employee_id FROM employee WHERE login = 'merch_demo'),
     '460000000003', 'Бутылка 500 мл', 'ООО Чистота');

INSERT INTO exchange_rate
(first_currency, second_currency, installation_date,
 exchange_rate_value)
VALUES
    ('RUB', 'RUB', '2026-10-03', 1),
    ('USD', 'RUB', '2026-10-03', 90),
    ('RUB', 'RUB', '2026-10-05', 1),
    ('EUR', 'RUB', '2026-10-03', 100);

-- делаем через конструкцию with .. returning чтобы знать uuid
-- создаем 4 тд, 3 пп
WITH
    sale_payment AS (
        INSERT INTO payment_order
            (currency, company_id, conclusion_date, payment_order_type,
             payment_order_id_in_bank, accountant_id, sum)
            VALUES
                ('RUB',
                 (SELECT company_id FROM company WHERE licence_id = 'LIC-001'),
                 '2026-10-03 12:00:00+03', 'входящее', 'BANK-IN-001',
                 (SELECT employee_id FROM employee WHERE login = 'accountant_demo'),
                 8700)
            RETURNING payment_order_id
    ),
    refund_payment AS (
        INSERT INTO payment_order
            (currency, company_id, conclusion_date, payment_order_type,
             payment_order_id_in_bank, accountant_id, sum)
            VALUES
                ('RUB',
                 (SELECT company_id FROM company WHERE licence_id = 'LIC-001'),
                 '2026-10-05 12:00:00+03', 'исходящее', 'BANK-OUT-001',
                 (SELECT employee_id FROM employee WHERE login = 'accountant_demo'),
                 1000)
            RETURNING payment_order_id
    ),
    usd_payment AS (
        INSERT INTO payment_order
            (currency, company_id, conclusion_date, payment_order_type,
             payment_order_id_in_bank, accountant_id, sum)
            VALUES
                ('RUB',
                 (SELECT company_id FROM company WHERE licence_id = 'LIC-002'),
                 '2026-10-03 15:00:00+03', 'входящее', 'BANK-IN-002',
                 (SELECT employee_id FROM employee WHERE login = 'accountant_demo'),
                 2700)
            RETURNING payment_order_id
    ),
    rub_invoices AS (
        INSERT INTO commerce_doc
            (currency, company_id, exchange_rate_id, payment_order_id,
             preparation_date, operation_date, manager_id, commerce_doc_type,
             origin_commerce_doc_id)
            SELECT
                'RUB',
                (SELECT company_id FROM company WHERE licence_id = 'LIC-001'),
                (SELECT exchange_rate_id FROM exchange_rate
                 WHERE first_currency = 'RUB' AND second_currency = 'RUB'
                   AND installation_date = '2026-10-03'),
                p.payment_order_id,
                v.preparation_date::timestamptz,
                '2026-10-03 12:00:00+03'::timestamptz,
                (SELECT employee_id FROM employee WHERE login = 'manager_demo'),
                'накладная',
                NULL
            FROM sale_payment AS p
                     CROSS JOIN (VALUES
                                     ('2026-10-03 09:00:00+03'),
                                     ('2026-10-03 09:30:00+03')
            ) AS v(preparation_date)
            RETURNING commerce_doc_id, preparation_date
    ),
    usd_invoice AS (
        INSERT INTO commerce_doc
            (currency, company_id, exchange_rate_id, payment_order_id,
             preparation_date, operation_date, manager_id, commerce_doc_type,
             origin_commerce_doc_id)
            SELECT
                'USD',
                (SELECT company_id FROM company WHERE licence_id = 'LIC-002'),
                (SELECT exchange_rate_id FROM exchange_rate
                 WHERE first_currency = 'USD' AND second_currency = 'RUB'
                   AND installation_date = '2026-10-03'),
                p.payment_order_id,
                '2026-10-03 13:00:00+03'::timestamptz,
                '2026-10-03 15:00:00+03'::timestamptz,
                (SELECT employee_id FROM employee WHERE login = 'manager_demo'),
                'накладная',
                NULL
            FROM usd_payment AS p
            RETURNING commerce_doc_id, preparation_date
    ),
    rub_return AS (
        INSERT INTO commerce_doc
            (currency, company_id, exchange_rate_id, payment_order_id,
             preparation_date, operation_date, manager_id, commerce_doc_type,
             origin_commerce_doc_id)
            SELECT
                'RUB',
                (SELECT company_id FROM company WHERE licence_id = 'LIC-001'),
                (SELECT exchange_rate_id FROM exchange_rate
                 WHERE first_currency = 'RUB' AND second_currency = 'RUB'
                   AND installation_date = '2026-10-05'),
                p.payment_order_id,
                '2026-10-05 10:00:00+03'::timestamptz,
                '2026-10-05 12:00:00+03'::timestamptz,
                (SELECT employee_id FROM employee WHERE login = 'manager_demo'),
                'возврат',
                d.commerce_doc_id
            FROM refund_payment AS p
                     CROSS JOIN rub_invoices AS d
            WHERE d.preparation_date = '2026-10-03 09:00:00+03'::timestamptz
            RETURNING commerce_doc_id, preparation_date
    )

-- 1 накладная - 5 упаковок сока по 1000 RUB
INSERT INTO transaction_record (item_id, commerce_doc_id, quantity, price)
VALUES (
           (SELECT i.item_id
            FROM item AS i
                     JOIN group_of_items AS g ON g.group_of_items_id = i.item_group
            WHERE g.group_name = 'Напитки' AND i.item_id_within_group = 1),
           (SELECT commerce_doc_id FROM rub_invoices
            WHERE preparation_date = '2026-10-03 09:00:00+03'),
           5, 1000
       );

-- 1 накладная - 3 бутылки воды по 500 RUB
INSERT INTO transaction_record (item_id, commerce_doc_id, quantity, price)
VALUES (
           (SELECT i.item_id
            FROM item AS i
                     JOIN group_of_items AS g ON g.group_of_items_id = i.item_group
            WHERE g.group_name = 'Напитки' AND i.item_id_within_group = 2),
           (SELECT commerce_doc_id FROM commerce_doc
            WHERE preparation_date = '2026-10-03 09:00:00+03'),
           3, 500
       );

-- 2 накладная - 2 упаковки сока по 1100 RUB
INSERT INTO transaction_record (item_id, commerce_doc_id, quantity, price)
VALUES (
           (SELECT i.item_id
            FROM item AS i
                     JOIN group_of_items AS g ON g.group_of_items_id = i.item_group
            WHERE g.group_name = 'Напитки' AND i.item_id_within_group = 1),
           (SELECT commerce_doc_id FROM commerce_doc
            WHERE preparation_date = '2026-10-03 09:30:00+03'),
           2, 1100
       );

-- 3 накладная - 2 бутылки воды по 15 USD
INSERT INTO transaction_record (item_id, commerce_doc_id, quantity, price)
VALUES (
           (SELECT i.item_id
            FROM item AS i
                     JOIN group_of_items AS g ON g.group_of_items_id = i.item_group
            WHERE g.group_name = 'Напитки' AND i.item_id_within_group = 2),
           (SELECT commerce_doc_id FROM commerce_doc
            WHERE preparation_date = '2026-10-03 13:00:00+03'),
           2, 15
       );

-- возврат - 1 упаковка сока по 1000 RUB
INSERT INTO transaction_record (item_id, commerce_doc_id, quantity, price)
VALUES (
           (SELECT i.item_id
            FROM item AS i
                     JOIN group_of_items AS g ON g.group_of_items_id = i.item_group
            WHERE g.group_name = 'Напитки' AND i.item_id_within_group = 1),
           (SELECT commerce_doc_id FROM commerce_doc
            WHERE preparation_date = '2026-10-05 10:00:00+03'),
           1, 1000
       );

INSERT INTO report (supervisor_id, creation_date)
VALUES ((SELECT employee_id FROM employee WHERE login = 'head_demo'),
        '2026-11-01');

COMMIT;
