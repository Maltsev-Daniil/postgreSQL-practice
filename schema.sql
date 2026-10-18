create table employee_job_title
(
    job_title_id   uuid primary key,
    job_title_name text
);

create type gender_enum as enum ('м', 'ж');

create table employee
(
    employee_id   uuid primary key,
    supervisor_id uuid references employee (employee_id),
    job_title_id  uuid references employee_job_title (job_title_id),

    -- регулярку чекнуть - физлица 12 длина
    -- юрлица 10 длина
    tin           text not null unique,
    login         text not null unique,
    passport      char(10),
    password      text,
    full_name     text,
    birthday_date date,
    gender        gender_enum,
    phone_number  char(12)
);

create table monetary_unit
(
    currency    varchar(3) primary key,
    country     varchar(20),
    description text
);

create table exchange_rate
(
    exchange_rate_id    uuid primary key,
    first_currency      varchar(3) references monetary_unit (currency),
    second_currency     varchar(3) references monetary_unit (currency),
    installation_date   date,
    exchange_rate_value numeric(17, 10)
);

create table report
(
    report_id     uuid primary key,
    supervisor_id uuid references employee (employee_id),
    creation_date date
);

create table group_of_items
(
    group_of_items_id uuid primary key,
    parental_group_id uuid references group_of_items (group_of_items_id),
    group_name        text,
    group_description text
);

create table item
(
    item_id              uuid primary key,
    item_group           uuid references group_of_items (group_of_items_id),
    item_name            text,
    certificate_id       varchar(30),
    item_quantity        integer,
    item_id_within_group integer unique,
    merchandiser_id      uuid references employee (employee_id),
    sku                  char(12),
    package              text,
    manufacturer_name    text
);

create table company_category
(
    company_category_id        uuid primary key,
    company_category_name      text,
    company_category_parent_id uuid references company_category (company_category_id)
);

create table company
(
    company_id          uuid primary key,
    company_category_id uuid references company_category (company_category_id),
    company_name        text,
    registered_address  text,
    phone_number        char(12),
    licence_id          varchar(30) not null unique,
    -- номер бик банка
    bank_bik            char(9)     not null
);

create type payment_order_type_enum as enum ('входящее', 'исходящее');
create type commerce_doc_type_enum as enum ('накладная', 'возврат');

create table payment_order
(
    payment_order_id         uuid primary key,
    currency                 varchar(3) references monetary_unit (currency),
    company_id               uuid references company (company_id),
    conclusion_date          timestamptz    not null,
    payment_order_type       payment_order_type_enum,
    payment_order_id_in_bank text           not null,
    accountant_id            uuid references employee (employee_id),
    sum                      numeric(12, 3) not null
);

create table commerce_doc
(
    commerce_doc_id        uuid primary key,
    currency               varchar(3) references monetary_unit (currency),
    company_id             uuid references company (company_id),
    exchange_rate_id       uuid references exchange_rate (exchange_rate_id),
    payment_order_id       uuid references payment_order (payment_order_id),
    preparation_date       timestamptz,
    operation_date         timestamptz,
    manager_id             uuid references employee (employee_id),
    commerce_doc_type      commerce_doc_type_enum,
    -- если тип тд - возврат то надо знать тд id о заключении
    origin_commerce_doc_id uuid references commerce_doc (commerce_doc_id)
);

create table transaction_record
(
    item_id         uuid references item (item_id),
    commerce_doc_id uuid references commerce_doc (commerce_doc_id),
    quantity        integer,
    price           numeric(12, 3)
);