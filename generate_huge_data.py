#!/usr/bin/env python3
"""Generate test data for the Volga sales department after schema.sql and seed.sql.

Run once on a freshly recreated database. PostgreSQL generates all UUID keys;
the script captures them with INSERT ... RETURNING. All changes use one transaction.
"""

import argparse
import getpass
import os
import random
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP

import psycopg


TZ = timezone(timedelta(hours=3))
MONEY = Decimal("0.001")


def one(cursor, query, params=()):
    """Require exactly one result row, so a missing or ambiguous seed fails early."""
    rows = cursor.execute(query, params).fetchall()
    if len(rows) != 1:
        raise RuntimeError(f"Expected one row, got {len(rows)} for: {query}")
    return rows[0]


def inserted_id(cursor, query, params):
    """Run a fixed INSERT ... RETURNING statement and return its new UUID."""
    return one(cursor, query, params)[0]


def days_of_year(year):
    day = date(year, 1, 1)
    end = date(year + 1, 1, 1)
    while day < end:
        yield day
        day += timedelta(days=1)


def money(value):
    return value.quantize(MONEY, rounding=ROUND_HALF_UP)


def generate(cursor, args):
    rng = random.Random(args.seed)
    year_days = list(days_of_year(args.year))

    if one(
        cursor,
        "SELECT EXISTS (SELECT 1 FROM company WHERE licence_id LIKE %s)",
        ("GEN-LIC-%",),
    )[0]:
        raise RuntimeError("Generated companies already exist. Recreate the database before running again.")
    if one(
        cursor,
        """SELECT EXISTS (
             SELECT 1 FROM exchange_rate
             WHERE installation_date >= %s AND installation_date < %s
           )""",
        (year_days[0], date(args.year + 1, 1, 1)),
    )[0]:
        raise RuntimeError("Rates already exist for this year. Choose another year or recreate the database.")

    categories = {
        name: one(
            cursor,
            "SELECT company_category_id FROM company_category WHERE company_category_name = %s",
            (name,),
        )[0]
        for name in ("Магазин", "Оптовик")
    }
    groups = {
        name: one(
            cursor,
            "SELECT group_of_items_id FROM group_of_items WHERE group_name = %s",
            (name,),
        )[0]
        for name in ("Напитки", "Бытовая химия")
    }
    employees = {
        login: one(cursor, "SELECT employee_id FROM employee WHERE login = %s", (login,))[0]
        for login in ("merch_demo", "manager_demo", "accountant_demo", "head_demo")
    }

    # Existing seed items use numbers 1 and 2 in Напитки, and 1 in Бытовая химия.
    next_number = {
        group_id: one(
            cursor,
            "SELECT COALESCE(MAX(item_id_within_group), 0) + 1 FROM item WHERE item_group = %s",
            (group_id,),
        )[0]
        for group_id in groups.values()
    }

    companies = []
    for number in range(1, args.companies + 1):
        category = "Магазин" if number % 3 else "Оптовик"
        company_id = inserted_id(
            cursor,
            """INSERT INTO company
               (company_category_id, company_name, registered_address,
                phone_number, licence_id, bank_bik)
               VALUES (%s, %s, %s, %s, %s, %s)
               RETURNING company_id""",
            (
                categories[category],
                f"ООО Тестовая фирма {number}",
                f"Москва, Тестовая улица, дом {number}",
                f"+7998{number:07d}",
                f"GEN-LIC-{number:06d}",
                f"04{number:07d}",
            ),
        )
        companies.append(company_id)

    initial_stock = max(1000, (args.invoices * 30 + args.items - 1) // args.items)
    items = []
    for number in range(1, args.items + 1):
        group_name = "Напитки" if number % 2 else "Бытовая химия"
        group_id = groups[group_name]
        local_number = next_number[group_id]
        next_number[group_id] += 1
        item_id = inserted_id(
            cursor,
            """INSERT INTO item
               (item_group, item_name, certificate_id, item_quantity,
                item_id_within_group, merchandiser_id, sku, package,
                manufacturer_name)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
               RETURNING item_id""",
            (
                group_id,
                f"Тестовый товар {number}",
                f"CERT-GEN-{number:06d}",
                initial_stock,
                local_number,
                employees["merch_demo"],
                f"47{number:010d}",
                "Штука",
                f"ООО Производитель {number % 20 + 1}",
            ),
        )
        items.append({"id": item_id, "stock": initial_stock, "rub_price": rng.randint(100, 5000)})

    # The head records rates for every day, including days when a rate repeats.
    rate_rows = []
    for day in year_days:
        rate_rows.extend(
            (
                ("RUB", "RUB", day, Decimal("1")),
                ("USD", "RUB", day, Decimal(rng.randint(8000, 10000)) / 100),
                ("EUR", "RUB", day, Decimal(rng.randint(9000, 11000)) / 100),
            )
        )
    cursor.executemany(
        """INSERT INTO exchange_rate
           (first_currency, second_currency, installation_date, exchange_rate_value)
           VALUES (%s, %s, %s, %s)""",
        rate_rows,
    )
    rates = {
        (day, currency): (rate_id, value)
        for rate_id, currency, day, value in cursor.execute(
            """SELECT exchange_rate_id, first_currency,
                      installation_date, exchange_rate_value
               FROM exchange_rate
               WHERE installation_date >= %s AND installation_date < %s
                 AND second_currency = 'RUB'""",
            (year_days[0], date(args.year + 1, 1, 1)),
        )
    }

    # Reserve part of the firms and items with no sales for LEFT JOIN queries.
    active_companies = companies[: max(1, args.companies * 4 // 5)]
    active_items = items[: max(1, args.items * 4 // 5)]
    invoices = []
    for number in range(1, args.invoices + 1):
        company_id = rng.choice(active_companies)
        day = rng.choice(year_days)
        currency = rng.choices(("RUB", "USD", "EUR"), weights=(7, 2, 1))[0]
        rate_id, rate_value = rates[(day, currency)]
        preparation = datetime.combine(day, time(rng.randint(8, 15), rng.randint(0, 59)), TZ)
        operation = preparation + timedelta(hours=2)

        available = [item for item in active_items if item["stock"] >= 8]
        if not available:
            raise RuntimeError("Not enough item stock for the requested invoice count.")
        selected = rng.sample(available, min(rng.randint(1, 4), len(available)))
        lines = []
        for item in selected:
            quantity = rng.randint(1, 8)
            rub_price = Decimal(item["rub_price"] * rng.randint(90, 110)) / 100
            price = money(rub_price / rate_value)
            lines.append((item, quantity, price))

        total_in_currency = sum((price * quantity for _, quantity, price in lines), Decimal(0))
        payment_sum = money(total_in_currency * rate_value)
        payment_id = inserted_id(
            cursor,
            """INSERT INTO payment_order
               (currency, company_id, conclusion_date, payment_order_type,
                payment_order_id_in_bank, accountant_id, sum)
               VALUES ('RUB', %s, %s, 'входящее', %s, %s, %s)
               RETURNING payment_order_id""",
            (company_id, operation, f"GEN-IN-{number:08d}",
             employees["accountant_demo"], payment_sum),
        )
        invoice_id = inserted_id(
            cursor,
            """INSERT INTO commerce_doc
               (currency, company_id, exchange_rate_id, payment_order_id,
                preparation_date, operation_date, manager_id,
                commerce_doc_type, origin_commerce_doc_id)
               VALUES (%s, %s, %s, %s, %s, %s, %s, 'накладная', NULL)
               RETURNING commerce_doc_id""",
            (currency, company_id, rate_id, payment_id, preparation, operation,
             employees["manager_demo"]),
        )
        for item, quantity, price in lines:
            cursor.execute(
                """INSERT INTO transaction_record
                   (item_id, commerce_doc_id, quantity, price)
                   VALUES (%s, %s, %s, %s)""",
                (item["id"], invoice_id, quantity, price),
            )
            changed = cursor.execute(
                """UPDATE item SET item_quantity = item_quantity - %s
                   WHERE item_id = %s AND item_quantity >= %s
                   RETURNING item_quantity""",
                (quantity, item["id"], quantity),
            ).fetchone()
            if changed is None:
                raise RuntimeError(f"Stock ran out for item {item['id']}")
            item["stock"] -= quantity
        invoices.append({
            "id": invoice_id, "company_id": company_id, "currency": currency,
            "date": day, "rate_id": rate_id, "rate": rate_value, "lines": lines,
        })

    returns = 0
    for invoice in invoices:
        if rng.random() >= args.return_rate or invoice["date"] >= year_days[-1]:
            continue
        item, sold_quantity, price = rng.choice(invoice["lines"])
        returned_quantity = rng.randint(1, sold_quantity)
        days_left = (year_days[-1] - invoice["date"]).days
        return_day = invoice["date"] + timedelta(days=rng.randint(1, min(14, days_left)))
        preparation = datetime.combine(return_day, time(10), TZ)
        operation = preparation + timedelta(hours=2)
        # The purchase-day rate is retained for the refund.
        refund_sum = money(price * returned_quantity * invoice["rate"])
        payment_id = inserted_id(
            cursor,
            """INSERT INTO payment_order
               (currency, company_id, conclusion_date, payment_order_type,
                payment_order_id_in_bank, accountant_id, sum)
               VALUES ('RUB', %s, %s, 'исходящее', %s, %s, %s)
               RETURNING payment_order_id""",
            (invoice["company_id"], operation, f"GEN-OUT-{returns + 1:08d}",
             employees["accountant_demo"], refund_sum),
        )
        return_id = inserted_id(
            cursor,
            """INSERT INTO commerce_doc
               (currency, company_id, exchange_rate_id, payment_order_id,
                preparation_date, operation_date, manager_id,
                commerce_doc_type, origin_commerce_doc_id)
               VALUES (%s, %s, %s, %s, %s, %s, %s, 'возврат', %s)
               RETURNING commerce_doc_id""",
            (invoice["currency"], invoice["company_id"], invoice["rate_id"],
             payment_id, preparation, operation, employees["manager_demo"],
             invoice["id"]),
        )
        cursor.execute(
            """INSERT INTO transaction_record
               (item_id, commerce_doc_id, quantity, price)
               VALUES (%s, %s, %s, %s)""",
            (item["id"], return_id, returned_quantity, price),
        )
        cursor.execute(
            "UPDATE item SET item_quantity = item_quantity + %s WHERE item_id = %s",
            (returned_quantity, item["id"]),
        )
        item["stock"] += returned_quantity
        returns += 1

    for month in range(1, 13):
        next_month = date(args.year + 1, 1, 1) if month == 12 else date(args.year, month + 1, 1)
        cursor.execute(
            "INSERT INTO report (supervisor_id, creation_date) VALUES (%s, %s)",
            (employees["head_demo"], next_month),
        )

    return {
        "companies": len(companies), "items": len(items),
        "rates": len(rate_rows), "invoices": len(invoices),
        "returns": returns, "reports": 12,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=os.getenv("PGHOST", "localhost"))
    parser.add_argument("--port", type=int, default=int(os.getenv("PGPORT", "5432")))
    parser.add_argument("--dbname", default=os.getenv("PGDATABASE", "magazine"))
    parser.add_argument("--user", default=os.getenv("PGUSER", getpass.getuser()))
    parser.add_argument("--year", type=int, default=2025)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--companies", type=int, default=50)
    parser.add_argument("--items", type=int, default=200)
    parser.add_argument("--invoices", type=int, default=2000)
    parser.add_argument("--return-rate", type=float, default=0.1)
    args = parser.parse_args()
    if not 2 <= args.companies <= 9_999_999:
        parser.error("--companies must be between 2 and 9999999")
    if not 2 <= args.items <= 9_999_999:
        parser.error("--items must be between 2 and 9999999")
    if args.invoices < 1:
        parser.error("--invoices must be positive")
    if not 0 <= args.return_rate <= 1:
        parser.error("--return-rate must be between 0 and 1")

    password = os.getenv("PGPASSWORD") or getpass.getpass("Пароль PostgreSQL: ")
    with psycopg.connect(
        host=args.host, port=args.port, dbname=args.dbname,
        user=args.user, password=password,
    ) as connection:
        with connection.cursor() as cursor:
            counts = generate(cursor, args)
    for name, count in counts.items():
        print(f"{name}: {count}")
    print("Готово: транзакция подтверждена.")


if __name__ == "__main__":
    main()
