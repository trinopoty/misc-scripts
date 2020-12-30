CREATE VIEW `wcl_report` AS SELECT m.name AS `Mine Name`, 
       (SELECT COUNT(1) FROM mine_employees me WHERE me.mine_id = m.id) AS `Total Employees`, 
       (SELECT COUNT(1) FROM mine_employees me WHERE me.mine_id = m.id AND me.mobile IS NOT NULL) AS `With Mobile`,
       (SELECT COUNT(1) FROM mine_employees me WHERE me.mine_id = m.id AND me.mobile IS NULL) AS `Without Mobile`,
       (SELECT COUNT(1) FROM mine_employees me RIGHT JOIN users u ON u.employee_id = me.id WHERE me.mine_id = m.id AND u.id IS NOT NULL) AS `Total Logins` FROM mines m WHERE m.id IN (218,222);
CREATE VIEW `all_report` AS SELECT m.name AS `Mine Name`, 
       (SELECT COUNT(1) FROM mine_employees me WHERE me.mine_id = m.id) AS `Total Employees`, 
       (SELECT COUNT(1) FROM mine_employees me WHERE me.mine_id = m.id AND me.mobile IS NOT NULL) AS `With Mobile`,
       (SELECT COUNT(1) FROM mine_employees me WHERE me.mine_id = m.id AND me.mobile IS NULL) AS `Without Mobile`,
       (SELECT COUNT(1) FROM mine_employees me RIGHT JOIN users u ON u.employee_id = me.id WHERE me.mine_id = m.id AND u.id IS NOT NULL) AS `Total Logins` FROM mines m;
