-- Active: 1730979093926@@127.0.0.1@5432@pbdi@public


---------------------------------------------------------------------
-- cliente
---------------------------------------------------------------------
drop table if exists tb_cliente;
create table if not exists tb_cliente (
  cod_cliente serial primary key,
  nome varchar(200) not null
);
select * from tb_cliente;


---------------------------------------------------------------------
-- pedido
---------------------------------------------------------------------
drop table if exists tb_pedido;
create table if not exists tb_pedido (
  cod_pedido serial primary key,
  data_criacao timestamp default current_timestamp,
  data_modificacao timestamp default current_timestamp,
  status varchar default 'aberto',
  cod_cliente int not null,
  constraint fk_cliente foreign key (cod_cliente) references tb_cliente(cod_cliente)
);
select * from tb_pedido;


---------------------------------------------------------------------
-- tipo do item
---------------------------------------------------------------------
drop table if exists tb_tipo_item;
create table if not exists tb_tipo_item(
  cod_tipo serial primary key,
  descricao varchar(200) not null
);
insert into tb_tipo_item (descricao) values ('Bebida'), ('Comida');
select * from tb_tipo_item;


---------------------------------------------------------------------
-- item
---------------------------------------------------------------------
drop table if exists tb_item;
create table if not exists tb_item(
  cod_item serial primary key,
  descricao varchar(200) not null,
  valor numeric (10, 2) not null,
  cod_tipo int not null,
  constraint fk_tipo_item foreign key (cod_tipo) references tb_tipo_item(cod_tipo)
);
insert into tb_item (descricao, valor, cod_tipo) values 
  ('Refrigerante', 7, 1), 
  ('Suco', 8, 1), 
  ('Hamburguer', 12, 2), 
  ('Batata frita', 9, 2);
select * from tb_item;


---------------------------------------------------------------------
-- relação item x pedido
---------------------------------------------------------------------
drop table if exists tb_item_pedido;
create table if not exists tb_item_pedido(
  --surrogate key, assim cod_item pode repetir
  cod_item_pedido serial primary key,
  cod_item int,
  cod_pedido int,
  constraint fk_item foreign key (cod_item) references tb_item (cod_item),
  constraint fk_pedido foreign key (cod_pedido) references tb_pedido (cod_pedido)
);
select * from tb_item_pedido;



---------------------------------------------------------------------
-- processos
---------------------------------------------------------------------

---------------------------------------------------------------------
-- processo de cadastro de cliente
-- se um parâmetro com valor default é especificado, aqueles que aparecem depois dele também deve ter valor default
---------------------------------------------------------------------
create or replace procedure sp_cadastrar_cliente (in nome varchar(200), in codigo int default null)
language plpgsql
as $$
begin
  if codigo is null then
    insert into tb_cliente (nome) values (nome);
  else
    insert into tb_cliente (codigo, nome) values (codigo, nome);
  end if;
end;
$$;
call sp_cadastrar_cliente ('João da Silva');
call sp_cadastrar_cliente ('Maria Santos');
select * from tb_cliente;


---------------------------------------------------------------------
-- criar um pedido, como se o cliente entrasse no restaurante e pegasse a comanda
---------------------------------------------------------------------
create or replace procedure sp_criar_pedido (out cod_pedido int, cod_cliente int)
language plpgsql
as $$
begin
  insert into tb_pedido (cod_cliente) values (cod_cliente);

  -- obtém o último valor gerado por serial
  select lastval() into cod_pedido;
end;
$$;

do $$
declare
  --para guardar o código de pedido gerado
  cod_pedido int;

  -- o código do cliente que vai fazer o pedido
  cod_cliente int;
begin
  -- pega o código da pessoa cujo nome é "joão da silva"
  select c.cod_cliente from tb_cliente c where nome like 'João da Silva' into cod_cliente;

  --cria o pedido
  call sp_criar_pedido (cod_pedido, cod_cliente);
  raise notice 'Código do pedido recém criado: %', cod_pedido;
end;
$$;



---------------------------------------------------------------------
-- adicionar um item a um pedido
---------------------------------------------------------------------
create or replace procedure sp_adicionar_item_a_pedido (in cod_item int, in cod_pedido int)
language plpgsql
as $$
begin
  --insere novo item
  insert into tb_item_pedido (cod_item, cod_pedido) values ($1, $2);

  --atualiza data de modificação do pedido
  update tb_pedido p set data_modificacao = current_timestamp where
  p.cod_pedido = $2;
end;
$$;
call sp_adicionar_item_a_pedido (1, 1);
select * from tb_item_pedido;
select * from tb_pedido;


---------------------------------------------------------------------
-- calcular valor total de um pedido
---------------------------------------------------------------------
drop procedure sp_calcular_valor_de_um_pedido;
create or replace procedure sp_calcular_valor_de_um_pedido (in p_cod_pedido int, out valor_total int)
language plpgsql
as $$
begin
  select sum(valor) from tb_pedido p
  inner join tb_item_pedido ip on p.cod_pedido = ip.cod_pedido
  inner join tb_item i on i.cod_item = ip.cod_item
  where p.cod_pedido = $1
  into $2;
end;
$$;

do $$
declare
  valor_total int;
begin
  call sp_calcular_valor_de_um_pedido(1, valor_total);
  raise notice 'Total do pedido %: R$%', 1, valor_total;
end;
$$;


---------------------------------------------------------------------
-- fechar pedido
---------------------------------------------------------------------
create or replace procedure sp_fechar_pedido (in valor_a_pagar int, in cod_pedido int)
language plpgsql
as $$
declare
  valor_total int;
begin
  --vamos verificar se o valor_a_pagar é suficiente
  call sp_calcular_valor_de_um_pedido (cod_pedido, valor_total);

  if valor_a_pagar < valor_total then
    raise 'R$% insuficiente para pagar a conta de R$%', valor_a_pagar, valor_total;
  else
    update tb_pedido p set
      data_modificacao = current_timestamp,
      status = 'fechado'
    where p.cod_pedido = $2;
  end if;
end;
$$;

do $$
begin
  call sp_fechar_pedido(200, 1);
end;
$$;
select * from tb_pedido;


---------------------------------------------------------------------
-- calcular o troco
---------------------------------------------------------------------
create or replace procedure sp_calcular_troco (out troco int, in valor_a_pagar int, in valor_total int)
language plpgsql
as $$
begin
  troco := valor_a_pagar - valor_total;
end;
$$;

do $$
declare
  troco int;
  valor_total int;
  valor_a_pagar int := 100;
begin
  call sp_calcular_valor_de_um_pedido(1, valor_total);
  call sp_calcular_troco (troco, valor_a_pagar, valor_total);
  raise notice 'a conta foi de r$% e você pagou %, portanto, seu troco é de r$%.', valor_total, valor_a_pagar, troco;
end;
$$


---------------------------------------------------------------------
-- obter notas para compor o troco
---------------------------------------------------------------------
create or replace procedure sp_obter_notas_para_compor_o_troco (out resultado varchar(500), in troco int)
language plpgsql
as $$
declare
  notas200  int := 0;
  notas100  int := 0;
  notas50   int := 0;
  notas20   int := 0;
  notas10   int := 0;
  notas5    int := 0;
  notas2    int := 0;
  moedas1   int := 0;
begin
  notas200  := troco / 200;
  notas100  := troco % 200 / 100;
  notas50   := troco % 200 % 100 / 50;
  notas20   := troco % 200 % 100 % 50 / 20;
  notas10   := troco % 200 % 100 % 50 % 20 / 10;
  notas5    := troco % 200 % 100 % 50 % 20 % 10 / 5;
  notas2    := troco % 200 % 100 % 50 % 20 % 10 % 5 / 2;
  moedas1   := troco % 200 % 100 % 50 % 20 % 10 % 5 % 2;
  resultado := concat (
    -- e é de escape. para que \n tenha sentido || é um operador de concatenação
    'Notas de 200: ', notas200 || E'\n',
    'Notas de 100: ', notas100 || E'\n',
    'Notas de 50: ', notas50 || E'\n',
    'Notas de 20: ', notas20 || E'\n',
    'Notas de 10: ', notas10 || E'\n',
    'Notas de 5: ', notas5 || E'\n',
    'Notas de 2: ', notas2 || E'\n',
    'Moedas de 1: ', moedas1 || E'\n'
  );
end;
$$;

do $$
declare
  resultado varchar(500);
  troco int := 43;
begin
  call sp_obter_notas_para_compor_o_troco (resultado, troco);
  raise notice '%', resultado;
end;
$$











-- drop prcedure if exists sp_calcula_media;
create or replace procedure sp_calcula_media(variadic p_valores int[])
language plpgsql
as $$
declare
  v_media numeric(10, 2) := 0;
  v_valor int;
begin
  foreach v_valor in array p_valores loop
    v_media := v_media + v_valor;
  end loop;

  raise notice 'A média é %', v_media / array_length(p_valores, 1);
end;
$$;

call sp_calcula_media(1);
call sp_calcula_media(1, 2);
call sp_calcula_media(1, 2, 5, 6, 1, 8);



-- declarar bloquinho anônimo
do $$
declare
  v_valor1 int := 1;
  v_valor2 int := 2;
begin
  call sp_acha_maior3(v_valor1, v_valor2);
  raise notice '%', v_valor1;

  v_valor1 := 4;
  call sp_acha_maior3(v_valor1, 2);
  raise notice '%', v_valor1;

  v_valor1 := 5;
  call sp_acha_maior3(v_valor1, 5);
  raise notice '%', v_valor1;
end;
$$;

-- drop prcedure if exists sp_acha_maior3;
create or replace procedure sp_acha_maior3(inout p_valor1 int, in p_valor2 int)
language plpgsql
as $$
begin
  if p_valor2 > p_valor1 then
    p_valor1 := p_valor2;
  end if;
end;
$$;


-- declarar bloquinho anônimo
do $$
declare
  v_resultado int;
begin
  call sp_acha_maior2(v_resultado, 1, 2);
  raise notice '%', v_resultado;
  call sp_acha_maior2(v_resultado, 4, 2);
  raise notice '%', v_resultado;
  call sp_acha_maior2(v_resultado, 5, 5);
  raise notice '%', v_resultado;
end;
$$;

-- drop prcedure if exists sp_acha_maior2;
create or replace procedure sp_acha_maior2(out p_resultado int, in p_valor1 int, in p_valor2 int)
language plpgsql
as $$
begin
  case
    when p_valor1 > p_valor2 then
      p_resultado := p_valor1;
    else
      $1 := p_valor2;
  end case;
end;
$$;



-- drop prcedure if exists sp_acha_maior;
create or replace procedure sp_acha_maior(in p_valor1 int, p_valor2 int)
language plpgsql
as $$
begin
  -- mostrar o maior usando parâmetros com nome e número, o primeiro com nome e o segundo com número
  if p_valor1 > p_valor2 then
    raise notice '%', p_valor1;
  elseif p_valor1 < p_valor2 then
    raise notice '%', p_valor2;
  else
    raise notice 'são iguais';
  end if;

  if $1 > $2 then
    raise notice '%', $1;
  elseif $1 < $2 then
    raise notice '%', $2;
  else
    raise notice 'são iguais';
  end if;
end;
$$;
call sp_acha_maior(1, 2);
call sp_acha_maior(4, 2);
call sp_acha_maior(5, 5);



create or replace procedure sp_ola_usuario(p_nome varchar(200))
language plpgsql
as $$
begin
  raise notice 'Olá, %', p_nome;
  raise notice 'Olá, %', $1;
end;
$$;
call sp_ola_usuario('Teste');



create or replace procedure sp_ola_procedures()
language plpgsql
as $$
begin
  raise notice 'Olá, procedures';
end;
$$;
call sp_ola_procedures();
