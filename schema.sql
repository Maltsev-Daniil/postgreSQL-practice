create table employee_job_title
(
    job_title_id   uuid primary key,
    job_title_name text not null,

    constraint chk_job_title_name
        check (btrim(job_title_name) <> '')
);

create type gender_enum as enum ('м', 'ж');

create table employee
(
    employee_id   uuid primary key,
    -- тут не нужен not null - у начальника нет начальника
    supervisor_id uuid references employee (employee_id),
    job_title_id  uuid        not null references employee_job_title (job_title_id),

    tin           char(12)    not null unique,
    login         text        not null unique,
    passport      char(10)    not null,
    password      text        not null,
    full_name     text        not null,
    birthday_date date        not null,
    gender        gender_enum not null,
    phone_number  char(12)    not null,

    constraint chk_employee_tin
        check (tin ~ '^[0-9]{12}$'),
    constraint chk_employee_login
        check (btrim(login) <> ''),
    constraint chk_employee_passport
        check (passport ~ '^[0-9]{10}$'),
    constraint chk_employee_password
        check (btrim(password) <> ''),
    constraint chk_employee_full_name
        check (btrim(full_name) <> ''),
    constraint chk_employee_phone
        check (phone_number ~ '^[+][0-9]{11}$'),
    constraint chk_employee_supervisor
        check (supervisor_id <> employee_id)
);

create table monetary_unit
(
    currency    varchar(3) primary key,
    country     varchar(20) not null,
    description text,

    constraint chk_currency_code
        check (currency ~ '^[A-Z]{3}$'),
    constraint chk_currency_country
        check (btrim(country) <> '')
);

create table exchange_rate
(
    exchange_rate_id    uuid primary key,
    first_currency      varchar(3)      not null references monetary_unit (currency),
    second_currency     varchar(3)      not null references monetary_unit (currency),
    installation_date   date            not null,
    exchange_rate_value numeric(17, 10) not null,
    unique (first_currency, second_currency, installation_date),

    constraint chk_exchange_rate_value
        check (
            exchange_rate_value > 0
                and exchange_rate_value <> 'NaN'::numeric
            ),
    constraint chk_exchange_rate_same_currency
        check (
            first_currency <> second_currency
                or exchange_rate_value = 1
            )
);

create table report
(
    report_id     uuid primary key,
    supervisor_id uuid not null references employee (employee_id),
    creation_date date not null
);

create table group_of_items
(
    group_of_items_id uuid primary key,
    parental_group_id uuid references group_of_items (group_of_items_id),
    group_name        text not null,
    group_description text,

    constraint chk_group_name
        check (btrim(group_name) <> ''),
    constraint chk_group_parent
        check (parental_group_id <> group_of_items_id)
);

create table item
(
    item_id              uuid primary key,
    item_group           uuid        not null references group_of_items (group_of_items_id),
    item_name            text        not null,
    certificate_id       varchar(30) not null,
    item_quantity        integer     not null,
    item_id_within_group integer     not null,
    merchandiser_id      uuid        not null references employee (employee_id),
    sku                  char(12)    not null,
    package              text        not null,
    manufacturer_name    text        not null,
    unique (item_group, item_id_within_group),

    constraint chk_item_name
        check (btrim(item_name) <> ''),
    constraint chk_item_certificate
        check (btrim(certificate_id) <> ''),
    constraint chk_item_quantity
        check (item_quantity >= 0),
    constraint chk_item_number
        check (item_id_within_group > 0),
    constraint chk_item_sku
        check (sku ~ '^[0-9]{12}$'),
    constraint chk_item_package
        check (btrim(package) <> ''),
    constraint chk_item_manufacturer
        check (btrim(manufacturer_name) <> '')
);

create table company_category
(
    company_category_id        uuid primary key,
    company_category_name      text not null,
    company_category_parent_id uuid references company_category (company_category_id),

    constraint chk_category_name
        check (btrim(company_category_name) <> ''),
    constraint chk_category_parent
        check (company_category_parent_id <> company_category_id)
);

create table company
(
    company_id          uuid primary key,
    company_category_id uuid        not null references company_category (company_category_id),
    company_name        text        not null,
    registered_address  text        not null,
    phone_number        char(12)    not null,
    licence_id          varchar(30) not null unique,
    -- номер бик банка
    bank_bik            char(9)     not null,

    constraint chk_company_name
        check (btrim(company_name) <> ''),
    constraint chk_company_address
        check (btrim(registered_address) <> ''),
    constraint chk_company_phone
        check (phone_number ~ '^[+][0-9]{11}$'),
    constraint chk_company_licence
        check (btrim(licence_id) <> ''),
    constraint chk_company_bik
        check (bank_bik ~ '^[0-9]{9}$')
);

create type payment_order_type_enum as enum ('входящее', 'исходящее');
create type commerce_doc_type_enum as enum ('накладная', 'возврат');

create table payment_order
(
    payment_order_id         uuid primary key,
    currency                 varchar(3)              not null references monetary_unit (currency),
    company_id               uuid                    not null references company (company_id),
    conclusion_date          timestamptz             not null,
    payment_order_type       payment_order_type_enum not null,
    payment_order_id_in_bank text                    not null,
    accountant_id            uuid                    not null references employee (employee_id),
    sum                      numeric(12, 3)          not null,

    constraint chk_payment_order_sum
        check (
            sum > 0
                and sum <> 'NaN'::numeric
            ),
    constraint chk_payment_order_bank_number
        check (btrim(payment_order_id_in_bank) <> '')
);

create table commerce_doc
(
    commerce_doc_id        uuid primary key,
    currency               varchar(3)             not null references monetary_unit (currency),
    company_id             uuid                   not null references company (company_id),
    exchange_rate_id       uuid references exchange_rate (exchange_rate_id),
    payment_order_id       uuid references payment_order (payment_order_id),
    preparation_date       timestamptz            not null,
    operation_date         timestamptz,
    manager_id             uuid                   not null references employee (employee_id),
    commerce_doc_type      commerce_doc_type_enum not null,
    -- если тип тд - возврат то надо знать тд id о заключении
    origin_commerce_doc_id uuid references commerce_doc (commerce_doc_id),

    constraint chk_commerce_doc_type
        check (
            (
                commerce_doc_type = 'накладная'
                    and origin_commerce_doc_id is null
                )
                or
            (
                commerce_doc_type = 'возврат'
                    and origin_commerce_doc_id is not null
                )
            ),
    constraint chk_commerce_doc_not_self
        check (origin_commerce_doc_id <> commerce_doc_id),
    constraint chk_commerce_doc_dates
        check (operation_date >= preparation_date),
    constraint chk_commerce_doc_payment_details
        check (
            operation_date is null
                or (
                payment_order_id is not null
                    and exchange_rate_id is not null
                )
            )
);

create table transaction_record
(
    item_id         uuid           not null references item (item_id),
    commerce_doc_id uuid           not null references commerce_doc (commerce_doc_id),
    quantity        integer        not null,
    price           numeric(12, 3) not null,
    primary key (item_id, commerce_doc_id),

    constraint chk_transaction_quantity
        check (quantity > 0),
    constraint chk_transaction_price
        check (
            price > 0
                and price <> 'NaN'::numeric
            )
);