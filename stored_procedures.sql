-- Active: 1726576516959@@localhost@1234@20242_ipi_pbdi_stephanie@public


-- 1.1 Adicione uma tabela de log ao sistema do restaurante. Ajuste cada procedimento para que ele registre:
-- A data em que a operação aconteceu;
-- O nome do procedimento executado.

-- ========================================================
-- Tabela de Log
-- ========================================================

-- Criação da tabela de log para registrar operações executadas
DROP TABLE IF EXISTS tb_log;

CREATE TABLE IF NOT EXISTS tb_log (
    cod_log      SERIAL PRIMARY KEY,     -- Código do log (chave primária, auto-incremento)
    procedimento VARCHAR(200) NOT NULL,  -- Nome do procedimento executado
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP   -- Data e hora da execução do log
    );

-- Visualizar os registros de log
SELECT * FROM   tb_log; 

-- ========================================================
-- Procedure Auxiliar para Geração de Logs
-- ========================================================

-- Criação de uma procedure auxiliar para inserir registros na tabela de log
CREATE OR REPLACE PROCEDURE sp_gera_log (
    IN procedimento VARCHAR(200)) -- Recebe o nome do procedimento a ser registrado
LANGUAGE plpgsql 
AS $$
BEGIN
    -- Inserção do log na tabela `tb_log`
    INSERT INTO tb_log (procedimento) VALUES (procedimento);
END;
$$;
-- Teste da procedure de log
-- CALL sp_gera_log('teste');
-- Verificação dos registros de log
SELECT * FROM tb_log;

-- ========================================================
-- Ajuste nas Procedures Existentes para Registro de Logs
-- ========================================================
-- ===================================
-- Procedure: Cadastro de Clientes
-- ===================================
CREATE OR REPLACE PROCEDURE sp_cadastrar_cliente (
    IN nome   VARCHAR(200),     -- Nome do cliente
    IN codigo INT DEFAULT NULL) -- Código do cliente (opcional)
LANGUAGE plpgsql
AS $$
BEGIN
    IF codigo IS NULL THEN
        -- Verifica se o código do cliente foi passado
        -- Inserção sem código (auto-incremento)
        INSERT INTO tb_cliente (nome) VALUES (nome);
    ELSE
        -- Inserção com código fornecido
        INSERT INTO tb_cliente (codigo, nome) VALUES (codigo, nome);
    END IF;
    -- Registro de log do procedimento
    CALL sp_gera_log('sp_cadastrar_cliente');
END;
$$;

-- ===================================
-- Procedure: Criação de Pedido
-- ===================================
CREATE OR REPLACE PROCEDURE sp_criar_pedido (
    OUT cod_pedido INT,   -- Código do pedido gerado
    IN cod_cliente INT)   -- Código do cliente
LANGUAGE plpgsql
AS $$
BEGIN
    -- Criação de um novo pedido para o cliente informado
    INSERT INTO tb_pedido (cod_cliente) VALUES (cod_cliente);

    -- Obtém o ID do último pedido inserido
    SELECT lastval() INTO cod_pedido;

    -- Registro de log do procedimento
    CALL sp_gera_log('sp_criar_pedido');
END;
$$;

-- ===================================
-- Procedure: Adicionar Item ao Pedido
-- ===================================
CREATE OR REPLACE PROCEDURE sp_adicionar_item_a_pedido (
    IN cod_item INT,   -- Código do item
    IN cod_pedido INT) -- Código do pedido
LANGUAGE plpgsql
AS $$
BEGIN
    -- Adiciona o item ao pedido na tabela de relação
    INSERT INTO tb_item_pedido (cod_item, cod_pedido) VALUES (cod_item, cod_pedido);

    -- Atualiza a data de modificação do pedido
    UPDATE tb_pedido p 
        SET data_modificacao = current_timestamp 
    WHERE p.cod_pedido = cod_pedido;

    -- Registro de log do procedimento
    CALL sp_gera_log('sp_adicionar_item_a_pedido');
END;
$$;

-- ===================================
-- Procedure: Calcular Valor Total de um Pedido
-- ===================================
CREATE OR REPLACE PROCEDURE sp_calcular_valor_de_um_pedido (
    IN p_cod_pedido INT,  -- Código do pedido
    OUT valor_total INT)  -- Valor total do pedido
LANGUAGE plpgsql
AS $$
BEGIN
    -- Calcula a soma dos valores dos itens do pedido
    SELECT SUM(i.valor) FROM tb_pedido p
    INNER JOIN tb_item_pedido ip ON ip.cod_pedido = p.cod_pedido
    INNER JOIN tb_item i ON i.cod_item = ip.cod_item
    WHERE p.cod_pedido = p_cod_pedido
    INTO valor_total;
  
  -- Registro de log do procedimento
    CALL sp_gera_log('sp_calcular_valor_de_um_pedido');
END;
$$;

-- ===================================
-- Procedure: Fechar Pedido
-- ===================================
CREATE OR REPLACE PROCEDURE sp_fechar_pedido (
    IN valor_entregue INT,  -- Valor entregue pelo cliente
    IN cod_pedido INT)      -- Código do pedido a ser fechado
LANGUAGE plpgsql
AS $$
DECLARE
    valor_total INT;  -- Variável para armazenar o valor total do pedido
BEGIN
    -- Chama a procedure para calcular o valor total do pedido
    CALL sp_calcular_valor_de_um_pedido(cod_pedido, valor_total);

    -- Verifica se o valor entregue é suficiente para pagar o pedido
    IF valor_entregue < valor_total THEN
        -- Exibe uma mensagem de erro se o valor for insuficiente
        RAISE NOTICE 'R$ % insuficiente para pagar a conta de R$ %', valor_entregue, valor_total;
    ELSE
        -- Atualiza o status do pedido para "fechado"
        UPDATE tb_pedido p SET
            data_modificacao = current_timestamp,
            status = 'fechado'
        WHERE p.cod_pedido = cod_pedido;
    END IF;

    -- Registro de log do procedimento
    CALL sp_gera_log('sp_fechar_pedido');
END;
$$;

-- ===================================
-- Procedure: Calcular Troco
-- ===================================
CREATE OR REPLACE PROCEDURE sp_calcular_troco (
    OUT troco INT,         -- Valor do troco a ser devolvido
    IN valor_a_pagar INT,  -- Valor a ser pago
    IN valor_total INT)    -- Valor total do pedido
LANGUAGE plpgsql
AS $$
BEGIN
    -- Calcula o troco subtraindo o valor total do valor pago
    troco := valor_a_pagar - valor_total;

    -- Registro de log do procedimento
    CALL sp_gera_log('sp_calcular_troco');
END;
$$;

-- ===================================
-- Procedure: Obter Notas para Compor o Troco
-- ===================================
CREATE OR REPLACE PROCEDURE sp_obter_notas_para_compor_o_troco (
    OUT resultado VARCHAR(500),  -- Resultado com a composição de notas e moedas
    IN troco INT)                -- Valor do troco a ser devolvido
LANGUAGE plpgsql
AS $$
DECLARE
    notas200  INT := 0;  -- Contador de notas de 200
    notas100  INT := 0;  -- Contador de notas de 100
    notas50   INT := 0;  -- Contador de notas de 50
    notas20   INT := 0;  -- Contador de notas de 20
    notas10   INT := 0;  -- Contador de notas de 10
    notas5    INT := 0;  -- Contador de notas de 5
    notas2    INT := 0;  -- Contador de notas de 2
    moedas1   INT := 0;  -- Contador de moedas de 1
BEGIN
    -- Calcula a quantidade de cada nota/moeda
    notas200  := troco / 200;
    notas100  := troco % 200 / 100;
    notas50   := troco % 200 % 100 / 50;
    notas20   := troco % 200 % 100 % 50 / 20;
    notas10   := troco % 200 % 100 % 50 % 20 / 10;
    notas5    := troco % 200 % 100 % 50 % 20 % 10 / 5;
    notas2    := troco % 200 % 100 % 50 % 20 % 10 % 5 / 2;
    moedas1   := troco % 200 % 100 % 50 % 20 % 10 % 5 % 2;

    -- Monta o resultado concatenando as informações
    resultado := concat(
        'Notas de 200: ', notas200 || E'\n',
        'Notas de 100: ', notas100 || E'\n',
        'Notas de 50: ', notas50 || E'\n',
        'Notas de 20: ', notas20 || E'\n',
        'Notas de 10: ', notas10 || E'\n',
        'Notas de 5: ', notas5 || E'\n',
        'Notas de 2: ', notas2 || E'\n',
        'Moedas de 1: ', moedas1 || E'\n'
    );

    -- Registro de log do procedimento
    CALL sp_gera_log('sp_obter_notas_para_compor_o_troco');
END;
$$;



-- 1.2 Adicione um procedimento ao sistema do restaurante. Ele deve
-- receber um parâmetro de entrada (IN) que representa o código de um cliente
-- exibir, com RAISE NOTICE, o total de pedidos que o cliente tem.

-- ================================================
-- Procedure: Calcular Total de Pedidos de um Cliente
-- ================================================
CREATE OR REPLACE PROCEDURE sp_total_cliente (
    IN v_cod_cliente INT)  -- Código do cliente
LANGUAGE plpgsql
AS $$
DECLARE
    valor_total INT;  -- Variável para armazenar o valor total dos pedidos
BEGIN
    -- Consulta para calcular a soma dos valores de todos os itens de pedidos do cliente
    SELECT SUM(i.valor)
    INTO valor_total
    FROM tb_pedido p
    INNER JOIN tb_item_pedido ip ON ip.cod_pedido = p.cod_pedido
    INNER JOIN tb_item i ON i.cod_item = ip.cod_item
    WHERE p.cod_cliente = v_cod_cliente;

    -- Verifica se o valor_total é NULL (caso não existam pedidos) e, se for, atribui 0
    IF valor_total IS NULL THEN
        valor_total := 0;
    END IF;

    -- Exibe uma mensagem com o total calculado
    RAISE NOTICE 'Total de pedidos: R$ %', valor_total;

    -- Registro de log do procedimento
    CALL sp_gera_log('sp_total_cliente');
END;
$$;


-- Exemplo de chamada:
-- Calcula e exibe o valor total dos pedidos feitos pelo cliente de código 1
CALL sp_total_cliente(1);

-- Visualizar os registros de log para verificar a execução
SELECT * FROM tb_log;



-- 1.3 Reescreva o exercício 1.2 de modo que o total de pedidos seja armazenado em uma variável de saída (OUT).

-- ================================================
-- Procedure: Calcular Total de Pedidos de um Cliente
-- ================================================
-- Remover a procedure existente, se houver
DROP PROCEDURE IF EXISTS sp_total_cliente;

-- Criar ou substituir a procedure
CREATE OR REPLACE PROCEDURE sp_total_cliente (
    IN v_cod_cliente INT,     -- Parâmetro de entrada: código do cliente
    OUT valor_total INT       -- Parâmetro de saída: valor total dos pedidos
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Consulta para calcular a soma dos valores de todos os itens dos pedidos do cliente
    SELECT SUM(i.valor)
    FROM tb_pedido p
    INNER JOIN tb_item_pedido ip ON ip.cod_pedido = p.cod_pedido
    INNER JOIN tb_item i ON i.cod_item = ip.cod_item
    WHERE p.cod_cliente = v_cod_cliente
    INTO valor_total;  -- Armazena o resultado na variável de saída 'valor_total'
END;
$$;

-- ================================================
-- Bloco anônimo para chamada da procedure e exibição do resultado
-- ================================================
DO $$
DECLARE
    valor_total INT;  -- Variável para armazenar o resultado da procedure
BEGIN
    -- Chamada da procedure passando o código do cliente e recebendo o valor total
    CALL sp_total_cliente(1, valor_total);
    
    -- Exibe uma mensagem com o total calculado
    RAISE NOTICE 'Total de pedidos: R$ %', valor_total;
END;
$$;

-- Exemplo de uso:
CALL sp_total_cliente(1, valor_total);



-- 1.4 Adicione um procedimento ao sistema do restaurante. Ele deve
-- Receber um parâmetro de entrada e saída (INOUT)
-- Na entrada, o parâmetro possui o código de um cliente
-- Na saída, o parâmetro deve possuir o número total de pedidos realizados pelo cliente

-- ================================================
-- Procedure: Calcular Total de Pedidos de um Cliente (Entrada e Saída)
-- ================================================

-- Criar ou substituir a procedure
CREATE OR REPLACE PROCEDURE sp_total_cliente_entrada_saida (
    INOUT entrada_saida INT  -- Parâmetro de entrada e saída
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Consulta para calcular a soma dos valores de todos os itens dos pedidos do cliente
    SELECT SUM(i.valor)
    FROM tb_pedido p
    INNER JOIN tb_item_pedido ip ON ip.cod_pedido = p.cod_pedido
    INNER JOIN tb_item i ON i.cod_item = ip.cod_item
    WHERE p.cod_cliente = entrada_saida  -- Utiliza o parâmetro 'entrada_saida' como filtro para o cliente
    INTO entrada_saida;  -- Armazena o resultado no próprio parâmetro 'entrada_saida'
END;
$$;

-- ================================================
-- Bloco anônimo para chamada da procedure e exibição do resultado
-- ================================================
DO $$
DECLARE
    entrada_saida INT := 1;  -- Inicializa a variável com o código do cliente
BEGIN
    -- Chama a procedure passando a variável 'entrada_saida'
    -- O valor da variável será atualizado com o total dos pedidos
    CALL sp_total_cliente_entrada_saida(entrada_saida);

    -- Exibe uma mensagem com o total calculado
    RAISE NOTICE 'Total de pedidos: R$ %', entrada_saida;
END;
$$;

-- Exemplo de uso
CALL sp_total_cliente_entrada_saida(entrada_saida);



-- 1.5 Adicione um procedimento ao sistema do restaurante. Ele deve
-- Receber um parâmetro VARIADIC contendo nomes de pessoas
-- Fazer uma inserção na tabela de clientes para cada nome recebido
-- Receber um parâmetro de saída que contém o seguinte texto:
-- “Os clientes: Pedro, Ana, João etc foram cadastrados”
-- Evidentemente, o resultado deve conter os nomes que de fato foram enviados por meio do parâmetro VARIADIC.

-- ================================================
-- Procedure: Cadastrar Múltiplos Clientes (Variadic)
-- ================================================

CREATE OR REPLACE PROCEDURE sp_cadastrar_cliente_variadic(
    OUT mensagem VARCHAR,    -- Parâmetro de saída para retornar a mensagem
    VARIADIC nomes VARCHAR[] -- Parâmetro variadic para receber múltiplos nomes de clientes
)
LANGUAGE plpgsql
AS $$
DECLARE
    nome VARCHAR;  -- Variável para iterar sobre os nomes do array
BEGIN
    -- Inicializa a mensagem
    mensagem := 'Os clientes: ';

    -- Loop para iterar sobre cada nome no array 'nomes'
    FOREACH nome IN ARRAY nomes LOOP
        -- Insere o nome do cliente na tabela 'tb_cliente'
        INSERT INTO tb_cliente (nome) VALUES (nome);

        -- Concatena o nome à mensagem
        mensagem := mensagem || nome || ', ';
    END LOOP;

    -- Remove a última vírgula e adiciona a mensagem final
    mensagem := substring(mensagem, 0, length(mensagem) - 1) || ' foram cadastrados';
END;
$$;

-- Exemplo de uso
-- Bloco para chamada da procedure e exibição do resultado
DO $$
DECLARE
    mensagem VARCHAR;  -- Variável para armazenar a mensagem de saída
BEGIN
    -- Chama a procedure passando três nomes de clientes
    CALL sp_cadastrar_cliente_variadic(mensagem, 'Maria', 'João', 'Ana');
    
    -- Exibe a mensagem de clientes cadastrados
    RAISE NOTICE '%', mensagem;
END;
$$;



-- 1.6 Para cada procedimento criado, escreva um bloco anônimo que o coloca em execução.
DO $$
DECLARE
    mensagem VARCHAR;  -- Declara uma variável para armazenar a mensagem de saída
BEGIN
    -- Chama a procedure para cadastrar clientes 'Pedro', 'Ana' e 'Paulo'
    CALL sp_cadastrar_cliente_variadic(mensagem, 'Pedro', 'Ana', 'Paulo');
    
    -- Exibe a mensagem de confirmação com os nomes dos clientes cadastrados
    RAISE NOTICE '%', mensagem;
END;
$$;

-- Consulta para verificar os clientes cadastrados
SELECT * FROM tb_cliente;