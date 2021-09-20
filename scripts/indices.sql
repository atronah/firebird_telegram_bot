create unique index idx_fbtb_command_uniq on fbtb_command(bot_id, command_name);

create index idx_fbtb_command_a_chat_list on fbtb_command computed by (coalesce(allowed_chat_id_list, ''));
create index idx_fbtb_command_a_user_list on fbtb_command computed by (coalesce(allowed_user_id_list, ''));