--1	� ����� ������� ������ ������ ���������?

select city as "�����", 							-- 1. �������� ������
	count(airport_code) as "���������� ����������"	-- � ���-�� ����������
from airports a										-- �� ������� airports
group by 1											-- 2. ���������� �� ������.
having count(airport_code)>1						-- 3. ������ ������� "��� ���������� ������ 1".


--2	� ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������?
--- ���������

select a.airport_name as "��������"								-- 1.�������� ���������
from airports a													-- �� ������� airports. 
left join flights f on f.departure_airport = a.airport_code		-- 2. ������������ ������� flights ��� ����������.
where f.aircraft_code = (select aircraft_code 					-- 3. ������ ������� ��� ������� ����� � ����� ����������
						from aircrafts 							-- ����������� ����� ��� ����������� ��� ��������,
						order by "range" desc limit 1)			-- � ������ ������ ��������� �� ��������  � ��� ���������� �����.	
group by 1;														-- 4. ���������� �� ��������� ��������.


--3	������� 10 ������ � ������������ �������� �������� ������
--- �������� LIMIT

select *,												-- 1. �������� �����.
	actual_departure - scheduled_departure as delay		-- 2. ��������� �������� ������� ������ �� "����. ����� ������ - ����� ������ �� ����������".
from flights 											-- 3. �� ����. flights.
where status like 'Arrived' 							-- 4. ������� ��� ���� ��� ��������
	or status like  'Departed'							-- ��� ��������� ��� � �����.
order by delay desc										-- 5. ��������� �� �������� delay.
limit 10;												-- 6. �������� 10 ������.


--4	���� �� �����, �� ������� �� ���� �������� ���������� ������?
--- ������ ��� JOIN

select b.book_ref as "����� ������������", 				-- 1. �������� ����� �����
		bp.boarding_no as "���������� �����"			-- � ���������� ������.
from boarding_passes bp									-- 2. �� ������� boarding_passes.
join tickets t on t.ticket_no = tf.ticket_no 			-- 3. ������������ ����. ��� ������: 3.1 ������� tickets;
right join bookings b on b.book_ref = t.book_ref 		-- 3.2 � ������� bookings ����� right join ��� ������ ���� ������������ ������.
where bp.boarding_no is null;							-- 4. ��������� ���������� ������, ��� ��� ��������


--5	������� ���������� ��������� ���� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������.
--�������� ������� � ������������� ������ - ��������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����. 
--�.�. � ���� ������� ������ ���������� ������������� ����� - ������� ������� ��� �������� 
--�� ������� ��������� �� ���� ��� ����� ������ ������ � ������� ���.
--- ������� �������
--- ���������� ���/� cte

with cte_seat_ac as 																					-- 1. ������ cte ��� ���������� ����
	(select aircraft_code, count(seat_no) as seats														-- � ������ ������ ������� 
	from seats s 																						-- �� ������� seats.
	group by aircraft_code),
cte_seat_bp as 																							-- 2. ������ cte ��� ���������� �������
	(select flight_id, count(seat_no) as seats															-- ���� � ������ �����
	from boarding_passes bp 																			-- �� ������� boarding_passes.
	group by flight_id)
select airport_name as "��������",																		-- 3. �������� ������ �������,
		scheduled_departure as "���� ������",															-- � ��������� ��������� ������������� ���� ���������� ���������� �� ������ ����
		free_seats as "��������� �����",																-- � ������ ��������� ����� ������� �������, �������� �� ���������
		"% ��������� ���� �� ���. ���-��",																-- � ��� ������, �������� �� ���� ������.
		sum(z_seats) over (partition by f.departure_airport,date_part('day',f.scheduled_departure) order by f.scheduled_departure) as "������������� ���� ���������� (����)"
from (select f.departure_airport,  																		-- 4. �� ������� � ������� ���������� ��� ���� cte
			f.scheduled_departure, 
			csb.seats as z_seats,
			csa.seats - csb.seats as free_seats,														-- � ��������� ���������� �����������
			round((csa.seats - csb.seats)::float/csa.seats * 100) as "% ��������� ���� �� ���. ���-��" 	-- ��������� ���� �� ������ ���-�� ���� � �������.
	from flights f																						-- 5. ���� ������ �� ������� floghts
	join cte_seat_ac csa on csa.aircraft_code = f.aircraft_code											-- ����������� ������ cte (�.1)
	join cte_seat_bp csb on csb.flight_id = f.flight_id													-- � ������� cte (�.2).
	group by 1,2,3,4,5) f																				-- 6. ����������.
join airports a on a.airport_code = f.departure_airport													-- 7. ������������ ��� ������� � �����������, ��� ����������� �������� ���������. 
order by airport_name, scheduled_departure																-- 8. ��������� �� ��������� + ���� ������.


--6	������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������.
--- ��������� ��� ����
--- �������� ROUND
	
select f.aircraft_code as "��� �������",																			-- 1. �������� ��� �������.
	round(count(f.flight_id)::float/(select count(flight_id) from flights)*100) as "���������� ��������, ����� (%)"-- 2. ��������� % ������ �� ���-�� �������� / ����� ���� �������� * 100.
from flights f 																										-- 3. �� ������� flights.
group by 1;																											-- 4. ���������� �� ���� ��������.


--7	���� �� ������, � ������� �����  ��������� ������ - ������� �������, ��� ������-������� � ������ ��������?
--- CTE
	
with cte_e as (											-- 1. ������ cte_e (����. �� cte_economy) 
	select flight_id ,									-- ��� ������� �������
	max(amount) as e_max, 								-- 
	fare_conditions 									-- 
	from ticket_flights tf 								-- �� ����. ticket_flights.
	where fare_conditions like 'Economy'				-- 2. ������� ��� ������ ������ "������" �����.
	group by 1,3										-- 
), cte_b as (											-- 3. ������ cte_b (����. �� cte_business) �� ������� �������
	select flight_id ,									-- ��� ������� �������
	min(amount) as b_min, 								-- � ������ ������� � ����������� �����.
	fare_conditions 									-- 
	from ticket_flights tf 								-- �� ����. ticket_flights.
	where fare_conditions like 'Business'				-- 4. ������� ��� ������ ������ "������" �����.
	group by 1,3										-- 
)
select f.flight_id as "� �������", 					-- 5. �������� ������ �������
		a.city as "����� �����������", 	-- 
		a2.city  as "����� ��������", 		-- 
		ce.e_max as "����. ���� ������ ��.", 			-- + ������� �� cte � �����.
		cb.b_min as "���. ���� ������ ��."				-- 
from flights f 	
join cte_e ce on ce.flight_id = f.flight_id 			-- 6. �������. cte_e.
join cte_b cb on cb.flight_id = f.flight_id				-- 7. �������. cte_b.
join airports a on a.airport_code = f.arrival_airport
join airports a2 on a2.airport_code = f.departure_airport 
where cb.b_min < ce.e_max								-- 8. ������ ������� ��������� ���� �� ������ � ������ �����.
group by 1,2,3,4,5


--8	����� ������ �������� ��� ������ ������?
--- ��������� ������������ � ����������� FROM
--- �������������� ��������� ������������� (���� �������� �����������, �� ��� �������������)
--- �������� EXCEPT

create view city_da as 										-- 1. ������ ������������� city_da (���� city departure arrival).
select distinct a.city as d_city, a2.city as a_city			-- 2. �������� ���������� �������� ������� �� ������� � ������������ � ������� � ������� ��������.
from flights f 												-- 3. �� ���� flights.
join airports a on a.airport_code = f.departure_airport 	-- 4. �������� ��������� � ���� airports ��� �������� ��� �����-����� (��� �����).
join airports a2 on a2.airport_code = f.arrival_airport;

select a.city, a2.city 										-- 5. ������ ������� �� �������� �����+�����.
from airports a, airports a2 								-- 6. �� ������� airports � 2.
where a.airport_code != a2.airport_code 					-- 7. ������ ������� ��� �� ������ �� ����������� � ����� ��������.
except 														-- 8. ��������
select d_city, a_city										-- ��� ������ 
from city_da												-- �� ����� ���������� ������������� (�.1).
order by 1;													-- 9. ���������� ��� �����������.


--9	��������� ���������� ����� �����������, ���������� ������� �������, �������� � ���������� ������������ ���������� ���������  � ���������, ������������� ��� ����� *	
--- �������� RADIANS ��� ������������� sind/cosd
--- CASE 

select 																																					-- 1. ��������
	distinct a.airport_name as "departure_airport(A)", 																									-- ���������� �������� ��������� �����������
	a2.airport_name as "arrival_airport(B)",																											-- � �������� ��������,
	round(acos(sind(a.latitude)*sind(a2.latitude) + cosd(a.latitude)*cosd(a2.latitude)*cosd(a.longitude - a2.longitude))*6371) as "range_from_A_to_B",	-- ��������� ���������� ����� ����,
	ac."range" as "aircraft_range",																														-- � ������� � ���������� ������� ������� � ���������.
	case when																																			-- 2. ����� case ������ �������
			ac."range" > acos(sind(a.latitude)*sind(a2.latitude) + cosd(a.latitude)*cosd(a2.latitude)*cosd(a.longitude - a2.longitude))*6371			-- ���� ��������� ������� ������� ������ ���������� ����� �����������,
		then '��'																																		-- �� ������ �������,
		else '���'																																		-- ���� ��� - ������ ���.
	end "successful_flight?"
from flights f																																			-- 3. �� ����. flights, ��� �� ������������
join airports a on a.airport_code = f.departure_airport 																								-- ������� airports �2, ��� ������ ������������ ���������
join airports a2 on a2.airport_code = f.arrival_airport 																								--
join aircrafts ac on ac.aircraft_code = f.aircraft_code  																								-- � ������� � �������� ������� ��� ������ �� ��������� �������.
order by 1;																																				-- 4. ��������� ��� ������� ������������.

