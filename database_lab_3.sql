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
