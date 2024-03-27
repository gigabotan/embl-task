SELECT * FROM wp_users;
INSERT INTO wp_users(ID,user_login,user_pass,user_nicename,user_email,user_url,user_registered,user_activation_key,user_status,display_name) VALUES(1,'user','$P$BD0diyRdVulvdIPOYXBL60HLP8VSd60','user','user@example.com','http://127.0.0.1','2024-03-27 12:32:31','',0,'user');
DELETE FROM wp_users WHERE ID=2;
