create table customers (
    customer_id serial primary key,
    full_name varchar(100) not null,
    email varchar(100) unique not null,
    balance numeric(10,2) default 0
);

create table products (
    product_id serial primary key,
    product_name varchar(100) not null,
    price numeric(10,2) not null,
    stock_quantity int not null
);

create table orders (
    order_id serial primary key,
    customer_id int references customers(customer_id),
    order_date timestamp default current_timestamp,
    total_amount numeric(10,2) default 0
);

create table order_items (
    order_item_id serial primary key,
    order_id int references orders(order_id),
    product_id int references products(product_id),
    quantity int not null,
    price numeric(10,2) not null
);

create table order_log (
    log_id serial primary key,
    order_id int,
    customer_id int,
    action varchar(50),
    log_date timestamp default current_timestamp
);

--task 1--
create function calculate_order_total(input_order_id int) --input order_id--
returns numeric(10,2)
language plpgsql
as $$
declare
    order_total numeric(10,2);
begin
    select coalesce(sum(quantity * price), 0) --0 instead of null--
    into order_total
    from order_items
    where order_id = input_order_id;

    return order_total;
end;
$$;

--task 2--
create procedure create_order(customer_id_input int)
language plpgsql
as $$
begin
    if not exists ( --check if exists--
        select 1
        from customers
        where customer_id = customer_id_input
    ) then
        raise exception 'customer with this id (%) not exist', customer_id_input; --stop if not--
    end if;

    insert into orders (customer_id, order_date, total_amount)
    values (customer_id_input, current_timestamp, 0); --create order--
end;
$$;

--task 3--
create procedure add_product_to_order(
    input_order_id int,
    input_product_id int,
    input_quantity int
)
language plpgsql
as $$
declare
    product_price numeric(10,2);
    available_stock int;
begin
    if input_quantity <= 0 then --check if quantity 0--
        raise exception 'quantity must be >=0';
    end if;

    if not exists ( --if order exist--
        select 1
        from orders
        where order_id = input_order_id
    ) then
        raise exception 'order with this id (%) not exist', input_order_id;
    end if;

    select price, stock_quantity
    into product_price, available_stock
    from products
    where product_id = input_product_id;

    if not found then --if product exist--
        raise exception 'product with this id (%) not exist', input_product_id;
    end if;

    if available_stock < input_quantity then --if enough stock available--
        raise exception 'not enough stock for product (%)',
            input_product_id;
    end if;

    insert into order_items (order_id, product_id, quantity, price) --add to order--
    values (input_order_id, input_product_id, input_quantity, product_price);

    update products -- -stock--
    set stock_quantity = stock_quantity - input_quantity
    where product_id = input_product_id;
end;
$$;

--task 4--
create function update_order_total()
returns trigger
language plpgsql
as $$
declare
    current_order_id int;
begin
    current_order_id := coalesce(new.order_id, old.order_id); --get id to insert, update, delete--

    update orders --update total--
    set total_amount = calculate_order_total(current_order_id)
    where order_id = current_order_id;

    return coalesce(new, old);
end;
$$;

create trigger trg_update_order_total_after_insert --insert--
after insert on order_items
for each row
execute function update_order_total();

create trigger trg_update_order_total_after_update --change quantity/price--
after update of quantity, price on order_items
for each row
execute function update_order_total();

create trigger trg_update_order_total_after_delete --delete--
after delete on order_items
for each row
execute function update_order_total();

--task 5--
create function log_order_creation()
returns trigger
language plpgsql
as $$
begin
    insert into order_log (order_id, customer_id, action, log_date) --add order info to log--
    values (new.order_id, new.customer_id, 'ORDER_CREATED', current_timestamp);

    return new;
end;
$$;

create trigger trg_log_order_creation --after order creation--
after insert on orders
for each row
execute function log_order_creation();

--task 6--
--tests--
insert into customers (full_name, email, balance)
values
    ('name1 surname1', 'name1@mail.com', 6700.00),
    ('name2 surname2', 'name2@mail.com', 6767.00);

insert into products (product_name, price, stock_quantity)
values
    ('prod1', 1000.00, 5),
    ('prod2', 2000.00, 10),
    ('prod3', 3000.00, 15);

--procedure--
call create_order(1);
call create_order(2);
call add_product_to_order(1, 1, 1);
call add_product_to_order(1, 2, 2);
call add_product_to_order(2, 3, 1);

--customers--
select *
from customers
order by customer_id;

--products+stock--
select *
from products
order by product_id;

--orders+totals
select *
from orders
order by order_id;

--order items--
select *
from order_items
order by order_item_id;

--calculation--
select calculate_order_total(1) as order_1_total;

--logs--
select *
from order_log
order by log_id;

--update--
update order_items
set quantity = 3
where order_id = 1
  and product_id = 2;

--total after update--
select order_id, total_amount
from orders
where order_id = 1;

--delete--
delete from order_items
where order_id = 1
  and product_id = 2;

--total after delete--
select order_id, total_amount
from orders
where order_id = 1;

--bonus--
explain analyze
select
    items.order_id,
    products.product_name,
    items.quantity,
    items.price,
    items.quantity * items.price as item_total
from order_items as items
join products as products
    on items.product_id = products.product_id
where items.order_id = 1;
