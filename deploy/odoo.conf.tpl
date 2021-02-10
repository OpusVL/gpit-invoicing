[options]
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo
proxy_mode = True
without_demo = True
admin_passwd = ${ADMIN_PASS}
db_host = ${rds_host}
db_port = 5432
db_user = odoo
db_password = ${RDS_PASS}
secure_cookie = True
; dbfilter = ^%h$
;
; auto_reload = True
; csv_internal_sep = ,
; db_maxconn = 64
; db_name = False
; db_template = template1
; dbfilter = .*
; debug_mode = True
; email_from = False
; limit_memory_hard = ${LIMIT_MEMORY_HARD}
; limit_memory_soft = ${LIMIT_MEMORY_SOFT}
limit_request = 8192
limit_time_cpu = ${LIMIT_TIME_CPU}
limit_time_real = ${LIMIT_TIME_REAL}
; list_db = True
; log_db = False
; log_handler = [':INFO']
; log_level = info
; logfile = None
longpolling_port = 8072
max_cron_threads = 0
; osv_memory_age_limit = 1.0
; osv_memory_count_limit = False
smtp_password = ${SMTP_PASSWORD}
smtp_port = 587
smtp_server = send.nhs.net
smtp_ssl = True
smtp_user = gpitf.invoicing@nhs.net
workers = 5
; xmlrpc = True
; xmlrpc_interface =
; xmlrpc_port = 8069
; xmlrpcs = True
; xmlrpcs_interface =
; xmlrpcs_port = 8071
