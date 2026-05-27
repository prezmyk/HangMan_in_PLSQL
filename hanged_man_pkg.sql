/*
    Creates and initializes a new game session.

    Responsibilities:
    - randomly selects a word
    - initializes counters
    - prepares masked word
    - sets session start timestamp
*/
create or replace PACKAGE hanged_man_pkg IS
/*
    Processes a single guessed letter.

    Responsibilities:
    - validates input
    - checks duplicate guesses
    - reveals matching letters
    - increments fail counter for incorrect guesses
    - checks win/lose conditions
*/
PROCEDURE guess_letter(p_letter VARCHAR2);

/*
    Allows player to guess the full word.
    Ends the game immediately on success or failure.
*/
PROCEDURE guess_word(p_word VARCHAR2);

/*
    Calculates total game duration from session start time.
*/
FUNCTION calculate_elapsed_time (p_start IN TIMESTAMP) 
RETURN INTERVAL DAY TO SECOND;


FUNCTION change_letter (p_string VARCHAR2, p_letter VARCHAR2, p_position NUMBER)
RETURN VARCHAR2;

SUBTYPE v_session IS game_sessions%ROWTYPE;

/*
    Creates and initializes a new game session.

    Responsibilities:
    - randomly selects a word
    - initializes counters
    - prepares masked word
    - sets session start timestamp
*/
FUNCTION init_game RETURN v_session;

PROCEDURE end_game(p_rec IN v_session, p_case IN NUMBER);

END hanged_man_pkg;
/


create or replace PACKAGE BODY hanged_man_pkg IS


PROCEDURE end_game(p_rec IN v_session, p_case IN NUMBER) IS
    v_result rankings.category%TYPE;
    v_hanged_man hanged_man.hanged_man%TYPE;
BEGIN
    IF p_case = 0 THEN 		
		v_result := UPPER('LOST');
		SELECT hanged_man INTO v_hanged_man FROM hanged_man WHERE hanged_man_id =  9;		
		dbms_output.put_line('--- GAME OVER ---');
		dbms_output.put_line('You were hanged!');
		dbms_output.put_line(v_hanged_man); 		
	ELSIF p_case = 1 THEN 
		v_result := UPPER('WIN');
		SELECT hanged_man INTO v_hanged_man FROM hanged_man WHERE hanged_man_id =  99;
		dbms_output.put_line('--- GAME OVER ---');
		dbms_output.put_line('You were saved!');
		dbms_output.put_line(v_hanged_man); 	
    ELSE
        DELETE FROM game_sessions WHERE username = USER;
        COMMIT;
        dbms_output.put_line('Time out');
        RETURN;    
	END IF;
	
	INSERT INTO rankings (USERNAME, word_ID, progress, category, days, attempts, duration, results, mistakes)
	VALUES (user, p_rec.word_id, p_rec.masked_word, p_rec.category, sysdate, p_rec.attempts_count, calculate_elapsed_time(p_rec.start_time), v_result ,p_rec.mistakes_count);
	--  cleaning
	DELETE FROM game_sessions WHERE username = USER;
	COMMIT;
END end_game;


PROCEDURE guess_letter(p_letter VARCHAR2) IS
    v_letter_flag       BOOLEAN DEFAULT FALSE;   
    v_game v_session;
    BEGIN 
		BEGIN
            SELECT *
			INTO v_game
			FROM game_sessions
			WHERE username = USER;
            
            IF calculate_elapsed_time(v_game.start_time) >=  INTERVAL '15' MINUTE THEN
                end_game(v_game,2);
                RETURN;
			END IF;
            
			EXCEPTION WHEN no_data_found THEN 			
				v_game := init_game();
				INSERT INTO game_sessions VALUES v_game;
		END;
		
		v_game.attempts_count := v_game.attempts_count +1;

        -- checking whether the letter has already been chosen
		IF INSTR(v_game.letters, ',' || LOWER(p_letter) || ',') > 0 THEN
			dbms_output.put_line(p_letter || ' has already been chosen');
			-- v_game.mistakes_count := v_game.mistakes_count+1;  
			RETURN;
		END IF;       


		IF LOWER(p_letter) IN ('a', 'ą', 'b', 'c', 'ć', 'd', 'e', 'ę', 'f', 'g',
							   'h', 'i', 'j', 'k', 'l', 'ł', 'm', 'n', 'ń', 'o',
							   'ó', 'p', 'r', 's', 'ś', 't', 'u', 'w', 'v', 'y', 'z',
							   'ź', 'ż', 'x', 'q') THEN
			dbms_output.put_line('The selected letter is ' || p_letter);
			-- add letter to list with coma separator
			v_game.letters := NVL(v_game.letters, ',') || LOWER(p_letter) || ',';
		ELSE
			dbms_output.put_line('This is not a letter');
			RETURN;
		END IF;


        -- Find the letters in a word
		FOR i IN 1 .. LENGTH(v_game.word)
		LOOP
			IF UPPER(SUBSTR(v_game.word, i, 1)) = UPPER(p_letter) THEN
				-- run the function to fill letters in the word
				v_game.masked_word := change_letter(v_game.masked_word, UPPER(p_letter), i);
				--  set flag to TRUE, no mistake
				v_letter_flag := TRUE;
			END IF;
		END LOOP;
		
		
		IF v_game.masked_word = v_game.word THEN
			end_game(v_game, 1);
			RETURN;
		END IF;
		
		-- mistakes counter when a letter was not found
        IF   v_letter_flag = FALSE THEN
            v_game.mistakes_count := v_game.mistakes_count+1;         
        END IF;       
		
        SELECT hanged_man INTO v_game.hanged_man FROM hanged_man WHERE hanged_man_id =  v_game.mistakes_count;
       
	   -- Mistakes limit, end game
        IF v_game.mistakes_count = 9 THEN
            end_game(v_game,0);
            RETURN;
        END IF;   

		-- Console output
        dbms_output.put_line('word:  '||v_game.masked_word||'  category: '||v_game.category); 
        dbms_output.put_line('Number of attempts: '||v_game.attempts_count);  
     -- dbms_output.put_line('Number of mistakes: '||v_game.mistakes_count); 
        dbms_output.put_line(v_game.hanged_man);  

		-- game_sessions save game block
		BEGIN
			MERGE INTO game_sessions gs
			USING (SELECT USER AS username FROM dual) src
			ON (gs.username = src.username)

			WHEN MATCHED THEN
			UPDATE SET
				gs.masked_word = v_game.masked_word,
				gs.mistakes_count   = v_game.mistakes_count,
				gs.attempts_count    = v_game.attempts_count,
				gs.hanged_man		= v_game.hanged_man,	
				gs.letters           = v_game.letters
			WHEN NOT MATCHED THEN
			INSERT 	VALUES v_game;
			
			COMMIT;
		END;

    END guess_letter;

PROCEDURE guess_word(p_word VARCHAR2) IS
    v_game v_session;
    BEGIN
		SELECT *
		INTO v_game
		FROM game_sessions
		WHERE username = USER;
        
        IF EXTRACT(MINUTE FROM calculate_elapsed_time(v_game.start_time)) >= 15 THEN
            end_game(v_game,2);
            RETURN;
        END IF;
		
		IF lower(p_word) = lower(v_game.word)  THEN
            end_game(v_game,1);
		ELSE
            end_game(v_game,0);	
		END IF; 
		
	EXCEPTION WHEN no_data_found THEN 			
		dbms_output.put_line('No word selected yet. Guess a letter.');
        RETURN;
			
    END guess_word;


FUNCTION calculate_elapsed_time(p_start IN TIMESTAMP)
RETURN INTERVAL DAY TO SECOND IS
	BEGIN
		RETURN SYSTIMESTAMP - p_start;
	END calculate_elapsed_time;

FUNCTION change_letter (p_string VARCHAR2, p_letter VARCHAR2, p_position NUMBER)
RETURN VARCHAR2 IS 
    v_string VARCHAR2(4000);
    BEGIN
        v_string := SUBSTR(p_string, 1 , p_position -1);
        v_string := CONCAT(v_string, SUBSTR(p_letter,1,1));
        v_string := CONCAT(v_string, SUBSTR(p_string, p_position+1));    
        RETURN v_string;
    END change_letter;


FUNCTION init_game RETURN v_session IS
    v_game v_session;
    BEGIN
        v_game.username := USER;

        SELECT word_id, word, category INTO v_game.word_id, v_game.word, v_game.category
        FROM ( SELECT word_id, word, category FROM words ORDER BY dbms_random.value )
        WHERE ROWNUM = 1;	
        -- create masked word
        SELECT REGEXP_REPLACE(word, '\w', '*') INTO v_game.masked_word FROM words WHERE word_id = v_game.word_id;
        v_game.mistakes_count := 0;
		v_game.attempts_count := 0;
        v_game.start_time := SYSTIMESTAMP;
        RETURN v_game;
    END;

END hanged_man_pkg;
/
