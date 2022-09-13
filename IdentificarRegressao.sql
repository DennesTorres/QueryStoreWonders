select * from sys.query_store_runtime_stats

-- plans with regressions
select query_id,qsrs.plan_id, first_execution_time,qsrs.last_execution_time,
	count_executions, avg_duration,
	last_duration,
	min_duration,
	max_duration,
	case
	 when lead(max_duration,1) over (partition by qsp.query_id order by qsrs.last_execution_time desc) > max_duration 
			then 'Improved'
	 when lead(max_duration,1) over (partition by qsp.query_id order by qsrs.last_execution_time desc) < max_duration 
			then 'Got Worse'
	end status	
  from sys.query_store_runtime_stats qsrs, sys.query_store_plan qsp
  where qsp.plan_id=qsrs.plan_id 

select * from sys.query_store_runtime_stats

-- Analisando queries parametrizadas pelo desvio padrão
-- dentro do stats_interval
select qsq.query_id,qsqt.query_sql_text,qsp.plan_id, 
		qsrs.max_duration,
		qsrs.max_cpu_time,
		qsrs.min_cpu_time,
		qsrs.min_duration,
		qsrs.stdev_duration,
		qsrs.stdev_cpu_time
from sys.query_store_query qsq, 
sys.query_store_query_text qsqt,
sys.query_store_plan qsp,
sys.query_store_runtime_stats qsrs
where qsq.query_text_id= qsqt.query_text_id 
and qsp.query_id=qsq.query_id
and qsrs.plan_id=qsp.plan_id
and (query_parameterization_type<>0 or qsq.object_id<>0)
and qsp.last_execution_time=(select max(last_execution_time)
								from sys.query_store_plan qsp2
								where qsp2.query_id= qsp.query_id)
order by stdev_cpu_time desc

select * from sys.query_store_runtime_stats

-- Plano atual de cada query
select query_id,plan_id from sys.query_store_query qsq
cross apply
(select top 1 plan_id from sys.query_store_plan qsp
where qsp.query_id=qsq.query_id
order by last_execution_time desc) plano

-- Plano atual de cada query
-- Incluindo o plano
select query_id,plan_id,query_plan from sys.query_store_query qsq
cross apply
	(select top 1 plan_id, convert(xml,query_plan) query_plan
	 from sys.query_store_plan qsp
	where qsp.query_id=qsq.query_id
	order by last_execution_time desc) plano

-- Desvio padrão entre capturas do plano mais atual
with qry as
	(select query_id,plan_id from sys.query_store_query qsq
	cross apply
		(select top 1 plan_id from sys.query_store_plan qsp
		where qsp.query_id=qsq.query_id
		order by last_execution_time desc) plano 
	)
select query_id,qry.plan_id,stdev(qsrs.max_cpu_time) stdevcpu
from qry, sys.query_store_runtime_stats qsrs
where qry.plan_id=qsrs.plan_id
group by query_id,qry.plan_id
order by stdevcpu desc

select * from sys.query_store_plan

select * from sys.query_store_query