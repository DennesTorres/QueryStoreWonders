use master
go

-- Creating the environment
drop database if exists qstore_demo

CREATE DATABASE [qstore_demo]
 ON  PRIMARY 
( NAME = N'qs_demo', FILENAME = N'C:\databases\qs_demo.mdf' , SIZE = 102400KB , 
		MAXSIZE = 1024000KB , FILEGROWTH = 20480KB )
 LOG ON 
( NAME = N'qs_demo_log', FILENAME = N'C:\databases\qs_demo_log.ldf' , SIZE = 50480KB , 
		MAXSIZE = 1024000KB , FILEGROWTH = 20480KB )
GO
ALTER DATABASE [qstore_demo] SET AUTO_UPDATE_STATISTICS OFF 
GO
ALTER DATABASE [qstore_demo] SET AUTO_CREATE_STATISTICS OFF 
GO
ALTER DATABASE [qstore_demo] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [qstore_demo] SET QUERY_STORE (INTERVAL_LENGTH_MINUTES = 1)
go
ALTER DATABASE [qstore_demo] SET QUERY_STORE  = OFF
GO

USE qstore_demo
GO

-- create a table
CREATE TABLE dbo.db_store 
(c1 CHAR(3) NOT NULL, 
c2 CHAR(3) NOT NULL, 
c3 SMALLINT NULL)
GO

-- create a stored procedure
CREATE PROC dbo.proc_1 @par1 SMALLINT
AS 
SET NOCOUNT ON
SELECT c1, c2 FROM dbo.db_store
WHERE c3 = @par1
GO

-- populate the table (this may take a couple of minutes)
SET NOCOUNT ON
begin transaction
go
INSERT INTO [dbo].db_store (c1,c2,c3) SELECT '18','2f',2
go 20000
INSERT INTO [dbo].db_store (c1,c2) SELECT '171','1ff'
go 4000  
INSERT INTO [dbo].db_store (c1,c2,c3) SELECT '172','1ff',0
go 10
INSERT INTO [dbo].db_store (c1,c2,c3)   SELECT '172','1ff',4 
go 15000
commit transaction
go


/*
     Mind the variation on the total of records
	 for each value fo the field c3
*/

-- enable Query Store on the database
ALTER DATABASE [qstore_demo] SET QUERY_STORE = ON
GO


-- First Execution
-- Check the graphic later
EXEC dbo.proc_1 0
GO 20

-- Creating an index
CREATE NONCLUSTERED INDEX NCI_1
ON dbo.db_store (c3)
GO

-- 2nd execution - query plan changed and improved
-- check the graphic again and compare the plans
EXEC dbo.proc_1 0
GO 20

-- dropping the index
drop index db_store.nci_1

-- clearing the cache
dbcc freeproccache
dbcc dropcleanbuffers

-- 3rd execution - query plan regressed
-- check the graphic again
EXEC dbo.proc_1 0
GO 20

-- New SQL Server 2017 feature
-- Tunning recomendations
select * from sys.dm_db_tuning_recommendations

-- Checking the status of the recomendation
SELECT reason, score,
      planForceState.*
FROM sys.dm_db_tuning_recommendations
  CROSS APPLY OPENJSON ([state])
    WITH (  [CurrentState] varchar(50) '$.currentValue',
            [StateReason] varchar(50) '$.reason'
          ) as planForceState

-- The script can be created from the json field
SELECT reason, score,
      JSON_VALUE(details, '$.implementationDetails.script') script,
      planForceDetails.*
FROM sys.dm_db_tuning_recommendations
  CROSS APPLY OPENJSON (Details, '$.planForceDetails')
    WITH (  [query_id] int '$.queryId',
            [regressed plan_id] int '$.regressedPlanId',
            [recommended plan_id] int '$.forcedPlanId'
          ) as planForceDetails


CREATE EVENT SESSION [ForcedPlansProblems] ON SERVER 
ADD EVENT qds.query_store_plan_forcing_failed(
    ACTION(sqlserver.sql_text))
ADD TARGET package0.ring_buffer
WITH (STARTUP_STATE=ON)
GO

-- Forcing a plan. Of course it won't work, but 
-- the plan will be forced
exec sp_query_store_force_plan @query_id = 1, @plan_id = 2

-- Identify forced plans
select * from sys.query_store_plan qsp,
sys.query_store_query qsq 
where qsq.query_id=qsp.query_id
and qsp.is_forced_plan=1


-- Check the plan again 
EXEC dbo.proc_1 0

-- Checking the status of the recomendation again
SELECT reason, score,
      planForceState.*
FROM sys.dm_db_tuning_recommendations
  CROSS APPLY OPENJSON ([state])
    WITH (  [CurrentState] varchar(50) '$.currentValue',
            [StateReason] varchar(50) '$.reason'
          ) as planForceState

-- Identify forced plan
-- Mind the failure of the forced plan
-- It's an important information to track
select plan_id,qsq.query_id,
		cast(query_plan as xml),
		is_forced_plan, force_failure_count,
		last_force_failure_reason,
		last_force_failure_reason_desc
from sys.query_store_plan qsp,
	sys.query_store_query qsq 
where qsq.query_id=qsp.query_id
	and qsp.is_forced_plan=1


CREATE NONCLUSTERED INDEX NCI_1
ON dbo.db_store (c3)
GO

-- check the execution plan again
EXEC dbo.proc_1 0

-- Check the forced plans again
-- The history about failures is still there
select plan_id,qsq.query_id,
		cast(query_plan as xml),
		is_forced_plan, force_failure_count,
		last_force_failure_reason,
		last_force_failure_reason_desc,
		qsp.count_compiles
from sys.query_store_plan qsp,
	sys.query_store_query qsq 
where qsq.query_id=qsp.query_id
	and qsp.is_forced_plan=1


-- High variation query
EXEC dbo.proc_1 0
GO 20
EXEC dbo.proc_1 2
GO 20
EXEC dbo.proc_1 0
GO 20
EXEC dbo.proc_1 2
GO 20

select * from dbo.QueriesWithParameterizationProblems()
  order by stdev_cpu_time desc

-- fixing the stored procedure
Alter procedure dbo.proc_1 @par1 SMALLINT
AS 
SET NOCOUNT ON
SELECT c1, c2 FROM dbo.db_store
WHERE c3 = @par1
  option (recompile)
GO

-- clearing the cache
dbcc freeproccache
dbcc dropcleanbuffers

-- trying again
EXEC dbo.proc_1 0
GO 20
EXEC dbo.proc_1 2
GO 20
EXEC dbo.proc_1 0
GO 20
EXEC dbo.proc_1 2
GO 20

select * from dbo.QueriesWithParameterizationProblems()
  order by stdev_cpu_time desc


	alter database current set query_store clear
	checkpoint
	dbcc freeproccache
	dbcc dropcleanbuffers
