Online store database with customers, products, orders, order items and order log.

- customers: store clients with name, email and balance
- products: product catalog with price and stock quantity
- orders: client orders with date and total amount
- order_items: products added to each order
- order_log: log of created orders

--calculate order total--

calculate_order_total function calculates the total order price using quantity * priceб if order has no products it returns 0

--create order--

create_order procedure creates a new order for an existing customer, prevents creating an order if the customer not exist

--add product to order--

add_product_to_order procedure

- checks if quantity > 0
- checks if order and product exist
- checks if there is enough product stock
- uses the current product price
- adds product to order_items
- decreases product stock quantity

--triggers--

trg_update_order_total automatically recalculates new total_amount after insert, update, delete in order_items

trg_log_order_creation adds a new record to order_log after order creation

--tests--

creates customers and products, creates orders using procedure and adds products to orders.

--checks--

- calculated order totals
- decreased product stock
- order creation logs
- total update after changing quantity
- total update after deleting order item
