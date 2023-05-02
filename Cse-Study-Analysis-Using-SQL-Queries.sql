-----
--1. Find customers who have never ordered
select user_id from users
where user_id not in (
    select distinct user_id from orders
    where user_id is not null
);

--2a. Average price of each food type
 with food_details as(
    select * from food f
    inner join menu m
    on f.f_id = m.f_id
)
select type, round(avg(price),2) as "Average Price",
median(price) as "Median Price",
stats_mode(price) as "Mode Price"
from food_details
group by type
order by "Average Price" desc;

--2b. Average price of food in each restaurants
with restaurant_details as (
    select * from restaurants r
    inner join orders o
    on r.r_id = o.r_id
    inner join menu m
    on r.r_id = m.r_id
)
select R_Name as "Restaurant Name", '$ '||round(avg(price),2) as  "Average Price"
from restaurant_details
group by R_Name
order by R_Name;

--3. Find the top restaurant in terms of the number of orders for all months
with res as (
select * from orders o
inner join restaurants r
on o.r_id = r.r_id
),
res_grouped as (
select to_char(order_date,'month') as order_month, r_name,
count(1) as order_count from res
group by extract(month from order_date),to_char(order_date,'month'),r_name
order by extract(month from order_date)
),
res_ranking as (
select order_month,r_name,
rank() over(partition by order_month order by order_count desc) as res_rank
from res_grouped
)
select ORDER_MONTH, R_NAME from res_ranking
where res_rank = 1
;

----- OPTIMIZED QUERY
WITH res AS (
    SELECT TO_CHAR(o.order_date, 'Month') AS order_month, 
    r.r_name, COUNT(*) AS order_count
    FROM orders o
    INNER JOIN restaurants r 
    ON o.r_id = r.r_id
    GROUP BY EXTRACT(month FROM o.order_date), TO_CHAR(o.order_date, 'Month'), r.r_name
)
SELECT order_month, r_name
FROM (
    SELECT order_month, r_name, 
    RANK() OVER (PARTITION BY order_month ORDER BY order_count DESC) AS res_rank
    FROM res
)
WHERE res_rank = 1
ORDER BY EXTRACT(month FROM TO_DATE(order_month, 'Month'));


--4. Find the top restaurant in terms of the number of orders for a  month = June
SELECT *
FROM restaurants r
INNER JOIN orders o
ON r.r_id = o.r_id
WHERE TRIM(TO_CHAR(o.ORDER_DATE, 'Month')) = 'June';

Note : The reason we use TRIM function is because TO_CHAR() takes the trailing spaces. So TRIM is used to remove any unecessary space.

--5. Restaurants with monthly sales greater than 500.
with res as (
SELECT to_char(o.order_date,'Month') as order_month ,r.r_name, sum(m.price) as price
FROM restaurants r
INNER JOIN orders o ON r.r_id = o.r_id
INNER JOIN menu m ON o.r_id = m.r_id
GROUP BY to_char(o.order_date,'Month'),r.r_name
having sum(m.price) >= 500
)
select * from res
order by extract(month from to_date(order_month,'Month')) asc;

Note : You can do ORDER BY on a column that is not mentioned in GROUP BY. Thats why we performed ORDER BY by using a CTE.
--order by o.order_date asc;


--6. Show all orders with order details for a particular customer in a particular date range (15th May 2022 to 15th June 2022)
select * from users u
inner join orders o
on u.user_id = o.user_id
where u.user_id = 1 and 
o.order_date between to_date('15-05-22','DD-MM-YY') and to_date('15-06-22','DD-MM-YY');

--7. Find restaurants with max repeated customers
with repeated_cust as (
select r.r_name,o.user_id,count(*) as order_count from restaurants r
inner join orders o
on r.r_id = o.r_id
group by r.r_name,o.user_id
having count(*)>1
), loyal_cust as(
select r_name,count(user_id) as "Repeated_customers" from repeated_cust
group by r_name
order by count(user_id) desc
)
select * from loyal_cust
where rownum = 1;

--8. Month over month revenue growth of swiggy
with month_rev as (
select to_char(o.order_date,'Month') as order_month ,sum(price) as monthly_rev
from orders o
inner join menu m
on o.r_id = m.r_id
group by to_char(o.order_date,'Month')
)
select order_month,
sum(monthly_rev) over(order by extract(month from to_date(order_month,'Month'))) as Rolling_Monthly_Rev
from month_rev
;


--9. Top 3 most ordered dish

--Using FETCH
select F_NAME,count(*) as order_count from order_details od
inner join food f
on f.f_id = od.f_id
group by F_NAME
order by order_count desc
FETCH FIRST 3 ROWS ONLY;

--Using ROWNUM
select F_name,order_count from (
select F_NAME,count(*) as order_count from order_details od
inner join food f
on f.f_id = od.f_id
group by F_NAME
order by order_count desc
)
where rownum <= 3
;


--10. Month over month revenue growth of each restaurant.
with res_grouped as (
select r.r_name, to_char(order_date,'Month') as order_month, sum(m.price) as price
from orders o
inner join restaurants r on o.r_id = r.r_id
inner join menu m on o.r_id = m.r_id
group by r.r_name, to_char(order_date,'Month')
)
select r_name,order_month,
sum(price) over(
    partition by r_name
    order by extract(Month from to_date(order_month,'Month')) asc
    ) as res_rolling__month_rev
from res_grouped
;
