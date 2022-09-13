
-- Creating the environmento
drop database if exists qstore_demo

CREATE DATABASE [qstore_demo]
 ON  PRIMARY 
( NAME = N'qs_demo', FILENAME = N'C:\databases\qs_demo.mdf' , SIZE = 102400KB , 
		MAXSIZE = 1024000KB , FILEGROWTH = 20480KB )
 LOG ON 
( NAME = N'qs_demo_log', FILENAME = N'C:\databases\qs_demo_log.ldf' , SIZE = 20480KB , 
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
CREATE TABLE dbo.db_store (c1 CHAR(3) NOT NULL, c2 CHAR(3) NOT NULL, 
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
INSERT INTO [dbo].db_store (c1,c2,c3) SELECT '18','2f',2
go 20000
INSERT INTO [dbo].db_store (c1,c2) SELECT '171','1ff'
go 4000  
INSERT INTO [dbo].db_store (c1,c2,c3) SELECT '172','1ff',0
go 10
INSERT INTO [dbo].db_store (c1,c2,c3)   SELECT '172','1ff',4 
go 15000

/*
     Observe a variação na quantidade de registros
	 de cada valor do campo c3
*/

-- enable Query Store on the database
ALTER DATABASE [qstore_demo] SET QUERY_STORE = ON
GO

-- First execution
-- check the graphic
EXEC dbo.proc_1 0
GO 20

-- Creating an index
-- far from pefect
CREATE NONCLUSTERED INDEX NCI_1
ON dbo.db_store (c3)
GO

-- 2nd execution
-- check the graphic and compare the plans
EXEC dbo.proc_1 0
GO 20

-- One more index
CREATE NONCLUSTERED INDEX NCI_2
ON dbo.db_store (c3, c1)
GO

-- 3rd execution
-- Compare the plans using the graphic
EXEC dbo.proc_1 0
GO 20


-- forcing a plan
-- (check the parameters)
EXEC sp_query_store_force_plan @query_id = 31, @plan_id = 38;
 
 -- 4th execution
 -- testing again
 -- the plan was forced
EXEC dbo.proc_1 0
GO 20

-- One more index, the better
CREATE NONCLUSTERED INDEX NCI_3
ON dbo.db_store (c3)
INCLUDE (c1,c2)

-- The execution doesn't identify it, because the plan is forced
EXEC dbo.proc_1 0
GO 20

-- Identify forced plans
select * from sys.query_store_plan qsp,
sys.query_store_query qsq 
where qsq.query_id=qsp.query_id
and qsp.is_forced_plan=1

-- remove the "plan force"
EXEC sp_query_store_unforce_plan @query_id = 31, @plan_id = 38
GO

-- The new index is identified
EXEC dbo.proc_1 0
GO 20

select * from sys.query_store_query 

-- queries in querystore
SELECT
  query_id,
  qt.query_sql_text AS 'Statement Text',
  [text] AS 'Query Batch Text'
FROM sys.query_store_query q
CROSS APPLY sys.dm_exec_sql_text(last_compile_batch_sql_handle)
INNER JOIN sys.query_store_query_text qt
  ON q.query_text_id = qt.query_text_id;

-- Removing the index to test parameterization
drop index db_store.nci_3

-- The parameter "2" needs a table scan, "0" needs the index
EXEC dbo.proc_1 2
GO 20

EXEC dbo.proc_1 0
GO 20


select * from dbo.QueriesWithParameterizationProblems()

-- fixing the stored procedure
Alter procedure dbo.proc_1 @par1 SMALLINT
AS 
SET NOCOUNT ON
SELECT c1, c2 FROM dbo.db_store
WHERE c3 = @par1
  option (recompile)
GO

EXEC dbo.proc_1 2
GO 20

EXEC dbo.proc_1 0
GO 20