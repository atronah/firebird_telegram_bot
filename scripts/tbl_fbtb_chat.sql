create table fbtb_chat(
   chat_id bigint
    , title varchar(255)
    , updated timestamp
    , constraint pk_fbtb_chat primary key (chat_id)
);

comment on table fbtb_chat is 'Stores information about telegram chats';
comment on column fbtb_chat.chat_id is 'todo:';

