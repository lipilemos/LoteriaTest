-- Criando o banco de dados
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'Loteria')
BEGIN
    CREATE DATABASE Loteria;
END
GO

USE Loteria;
GO

-- Criando a tabela de Usuario
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Usuario')
BEGIN
    CREATE TABLE Usuario (
        UsuarioID INT PRIMARY KEY IDENTITY(1,1), -- ID único do usuário
        Nome NVARCHAR(100),
        CPF NVARCHAR(14),
        Email NVARCHAR(100),
        QuantidadeNumerosSorte INT CHECK (QuantidadeNumerosSorte BETWEEN 1 AND 10) -- Quantidade de números da sorte entre 1 e 10
    );
END
GO

-- Criando a tabela de Cupons
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Cupons')
BEGIN
    CREATE TABLE Cupons (
        CupomID INT PRIMARY KEY IDENTITY(1,1), -- ID único do cupom
        UsuarioID INT FOREIGN KEY REFERENCES Usuario(UsuarioID), -- Chave estrangeira para a tabela Usuario
        NumeroSorte INT UNIQUE CHECK (NumeroSorte BETWEEN 0 AND 99999999) -- Número da sorte único entre 0 e 99999999
    );
END
GO

-- Populando a tabela de Usuario com dados fake Usuario1, emailuser1@dominio.com, 12345678909, (0+1) - (9+1) positivos
INSERT INTO Usuario (Nome, CPF, Email, QuantidadeNumerosSorte)
SELECT TOP 1000
    'Usuario' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(10)), -- Nome fake
    CAST(ABS(CHECKSUM(NEWID())) % 1000000000 AS NVARCHAR(11)), -- CPF fake
    'emailuser' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS NVARCHAR(10)) + '@dominio.com', -- Email fake
    ABS(CHECKSUM(NEWID())) % 10 + 1 -- Quantidade de números da sorte entre 1 e 10
    -- ***
FROM master.dbo.spt_values;

-- Populando a tabela de Cupons com números únicos
DECLARE @UserID INT;
DECLARE @NumSorte INT;
-- ****
DECLARE UserCursors CURSOR FOR
SELECT UsuarioID, QuantidadeNumerosSorte
FROM Usuario;

OPEN UserCursors;

FETCH NEXT FROM UserCursors INTO @UserID, @NumSorte;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @Counter INT = 1;
    WHILE @Counter <= @NumSorte
    BEGIN
        INSERT INTO Cupons (UsuarioID, NumeroSorte)
        VALUES (@UserID, ABS(CHECKSUM(NEWID())) % 100000000); -- Número da sorte fake entre 0 e 99999999 - (positivo) - unico

        SET @Counter = @Counter + 1;
    END

    FETCH NEXT FROM UserCursors INTO @UserID, @NumSorte;
END

CLOSE UserCursors;
DEALLOCATE UserCursors;

-- Procedure para apuração do ganhador randomico
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'ApuracaoGanhadoresRandom')
BEGIN
    EXEC('CREATE PROCEDURE ApuracaoGanhadoresRandom 
    AS
    BEGIN
    DECLARE @ResultadoLoteria INT;

        -- Gerando um número aleatório para representar o resultado da loteria entre 0 e 99999999
        -- *
        SET @ResultadoLoteria = ABS(CAST(RAND() * 100000000 AS INT));

        -- Buscar ganhador com número de sorte exato
        SELECT TOP 1
            U.Nome,
            U.CPF,
            U.Email,
            C.NumeroSorte,
            @ResultadoLoteria AS NumeroSorteado
        FROM Usuario U 
        INNER JOIN Cupons C ON U.UsuarioID = C.UsuarioID 
        WHERE C.NumeroSorte = @ResultadoLoteria
        ORDER BY C.NumeroSorte;

        -- Se nenhum ganhador encontrado, procurar o número mais próximo
        IF @@ROWCOUNT = 0 
        BEGIN
            SELECT TOP 1
                U.Nome,
                U.CPF,
                U.Email,
                C.NumeroSorte,
                @ResultadoLoteria AS NumeroSorteado
            FROM Usuario U
            INNER JOIN Cupons C ON U.UsuarioID = C.UsuarioID
            -- **
            ORDER BY ABS(C.NumeroSorte - @ResultadoLoteria), C.NumeroSorte;
        END;
    END;');
END
GO

-- Procedure para apuração dos ganhadores com numero de entrada 
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'ApuracaoGanhadores')
BEGIN
    EXEC('CREATE PROCEDURE ApuracaoGanhadores @ResultadoLoteria INT
    AS
    BEGIN
        -- Buscar ganhador com número de sorte exato
        SELECT TOP 1
            U.Nome,
            U.CPF,
            U.Email,
            C.NumeroSorte,
            @ResultadoLoteria AS NumeroSorteado
        FROM Usuario U
        INNER JOIN Cupons C ON U.UsuarioID = C.UsuarioID
        WHERE C.NumeroSorte = @ResultadoLoteria
        ORDER BY C.NumeroSorte;

        -- Se nenhum ganhador encontrado, procurar o número mais próximo
        IF @@ROWCOUNT = 0
        BEGIN
            SELECT TOP 1
                U.Nome,
                U.CPF,
                U.Email,
                C.NumeroSorte,
                @ResultadoLoteria AS NumeroSorteado
            FROM Usuario U
            INNER JOIN Cupons C ON U.UsuarioID = C.UsuarioID
            -- **
            ORDER BY ABS(C.NumeroSorte - @ResultadoLoteria), C.NumeroSorte;
        END;
    END;');
END
GO

--fontes(ajudinha):
-- * https://dba-pro.com/como-gerar-numeros-aleatorios-no-sql/
-- ** https://qastack.com.br/dba/138516/how-to-write-a-query-in-sql-server-to-find-nearest-values
-- *** https://stackoverflow.com/questions/4273723/what-is-the-purpose-of-system-table-master-spt-values-and-what-are-the-meanings
-- **** https://learn.microsoft.com/pt-br/sql/t-sql/language-elements/declare-cursor-transact-sql?view=sql-server-ver16