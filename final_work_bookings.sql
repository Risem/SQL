--БД https://edu.postgrespro.ru/bookings.pdf
--(излишки комментарий было для проверки что всё понял)

--1	В каких городах больше одного аэропорта?

select city as "Город",
	count(airport_code) as "Количество аэропортов"
from airports a
group by 1
having count(airport_code)>1


--2	В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?
--- Подзапрос

select a.airport_name as "Аэропорт"
from airports a
left join flights f on f.departure_airport = a.airport_code
where f.aircraft_code = (select aircraft_code 			-- Ставим условие при котором найдём в каких аэропортах
			from aircrafts 				-- совершаются полёты при необходимых нам условиях,
			order by "range" desc limit 1)		-- В данном случае фильтруем по самолётам  с мах дальностью полёта.	
group by 1;


--3	Вывести 10 рейсов с максимальным временем задержки вылета
--- Оператор LIMIT

select *,
	actual_departure - scheduled_departure as delay		-- Вычисляем задержку времени исходя из "факт. время вылета - время вылета по расписанию".
from flights
where status like 'Arrived' 					-- 4. Условие что рейс был выполнен
	or status like  'Departed'				-- или находится уже в полёте.
order by delay desc
limit 10;


--4	Были ли брони, по которым не были получены посадочные талоны?
--- Верный тип JOIN

select b.book_ref as "Номер бронирования",
		bp.boarding_no as "Посадочный талон"
from boarding_passes bp
join tickets t on t.ticket_no = tf.ticket_no
right join bookings b on b.book_ref = t.book_ref
where bp.boarding_no is null;				-- Фильтруем посадочные талоны, где нет значений


--5	Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
--Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
--Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело 
--из данного аэропорта на этом или более ранних рейсах в течении дня.
--- Оконная функция
--- Подзапросы или/и cte

with cte_seat_ac as 							-- Создаём cte для вычисления мест
	(select aircraft_code, count(seat_no) as seats			-- в каждой модели самолёта 
	from seats s 							-- из таблицы seats.
	group by aircraft_code),
cte_seat_bp as 								-- Создаём cte для вычисления занятых
	(select flight_id, count(seat_no) as seats			-- мест в каждом рейсе
	from boarding_passes bp 					-- из таблицы boarding_passes.
	group by flight_id)
select airport_name as "Аэропорт",
	scheduled_departure as "Дата вылета",				-- в последней вычисляем накопительный итог вылетевших пассажиров за каждый день
	free_seats as "Свободные места",				-- в каждом аэропорту через оконную функцию, разделяя по аэропорту
	"% свободных мест от общ. кол-ва",				-- и дню вылета, сортируя по дате вылета.
	sum(z_seats) over (partition by f.departure_airport,date_part('day',f.scheduled_departure) order by f.scheduled_departure) as "Накопительный итог пассажиров (день)"
from (select f.departure_airport,
		f.scheduled_departure, 
		csb.seats as z_seats,
		csa.seats - csb.seats as free_seats,			-- и вычислили процентное соотношение
		round((csa.seats - csb.seats)::float/csa.seats * 100) as "% свободных мест от общ. кол-ва" 	-- свободных мест от общего кол-ва мест в самолёте.
	from flights f
	join cte_seat_ac csa on csa.aircraft_code = f.aircraft_code
	join cte_seat_bp csb on csb.flight_id = f.flight_id
	group by 1,2,3,4,5) f
join airports a on a.airport_code = f.departure_airport			-- Присоединяем ещё таблицу с аэропортами, для отображения названия аэропорта. 
order by airport_name, scheduled_departure


--6	Найдите процентное соотношение перелетов по типам самолетов от общего количества.
--- Подзапрос или окно
--- Оператор ROUND
	
select f.aircraft_code as "Тип самолёта",
	round(count(f.flight_id)::float/(select count(flight_id) from flights)*100) as "Количество перелётов, всего (%)"-- 2. Вычисляем % исходя из кол-во перелётов / сумма всех перелётов * 100.
from flights f
group by 1;


--7	Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?
--- CTE
	
with cte_e as (						-- Создаём cte_e для выборки билетов
	select flight_id ,				-- для выбора только "Эконом" класс.
	max(amount) as e_max, 
	fare_conditions 
	from ticket_flights tf 
	where fare_conditions like 'Economy'
	group by 1,3
), cte_b as (						-- Создаём cte_b для выборки билетов
	select flight_id ,				-- в рамках перелёта с минимальной ценой.
	min(amount) as b_min,				-- для выбора только "Бизнес" класс.
	fare_conditions
	from ticket_flights tf
	where fare_conditions like 'Business'
	group by 1,3
)
select f.flight_id as "№ перелёта",
		a.city as "Город отправления",
		a2.city  as "Город прибытия",
		ce.e_max as "Макс. цена эконом кл.",
		cb.b_min as "Мин. цена бизнес кл."
from flights f 	
join cte_e ce on ce.flight_id = f.flight_id
join cte_b cb on cb.flight_id = f.flight_id
join airports a on a.airport_code = f.arrival_airport
join airports a2 on a2.airport_code = f.departure_airport 
where cb.b_min < ce.e_max				-- Ставим условие сравнения цены за эконом и бизнес класс.
group by 1,2,3,4,5


--8	Между какими городами нет прямых рейсов?
--- Декартово произведение в предложении FROM
--- Самостоятельно созданные представления (если облачное подключение, то без представления)
--- Оператор EXCEPT

create view city_da as 						-- 1. Создаём представление city_da
select distinct a.city as d_city, a2.city as a_city		-- 2. Выбираем уникальные значения колонки из столбца с отправлением и столбец с городом прибытия.
from flights f
join airports a on a.airport_code = f.departure_airport
join airports a2 on a2.airport_code = f.arrival_airport;

select a.city, a2.city 						-- 3. Делаем выборку по столбцам город+город.
from airports a, airports a2
where a.airport_code != a2.airport_code 			-- 4. Ставим условие что бы города не повторялись в обоих столбцах.
except 								-- 5. Иключаем наш список из ранее созданного представления (п.1).
select d_city, a_city
from city_da
order by 1;


--9	Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы *	
--- Оператор RADIANS или использование sind/cosd
--- CASE 

select
	distinct a.airport_name as "departure_airport(A)",
	a2.airport_name as "arrival_airport(B)",
	round(acos(sind(a.latitude)*sind(a2.latitude) + cosd(a.latitude)*cosd(a2.latitude)*cosd(a.longitude - a2.longitude))*6371) as "range_from_A_to_B",
	ac."range" as "aircraft_range",
	case when																		-- Через case делаем условие:
			ac."range" > acos(sind(a.latitude)*sind(a2.latitude) + cosd(a.latitude)*cosd(a2.latitude)*cosd(a.longitude - a2.longitude))*6371	-- если дальность перелёта самолёта больше расстояния между аэропортами,
		then 'да'																	-- то самолёт долетит,
		else 'нет'																	-- если нет - значит нет.
	end "successful_flight?"
from flights f
join airports a on a.airport_code = f.departure_airport 
join airports a2 on a2.airport_code = f.arrival_airport
join aircrafts ac on ac.aircraft_code = f.aircraft_code
order by 1;

