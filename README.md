# HangMan in PL/SQL

A console Hangman game implemented entirely in PL/SQL and Oracle SQL.

This project started as a personal experiment created while learning PL/SQL from books and online courses, before working professionally as an analyst.

The goal was to explore how far PL/SQL can be pushed beyond typical business procedures by implementing a small interactive game.

Later, the project was refactored to improve:
- code readability
- naming conventions
- timestamp handling
- session persistence
- game state management
- package structure


## Features

- Random word selection from database
- Letter guessing
- Full word guessing
- Automatic win/lose detection
- 15-minute session timeout
- Session persistence using `GAME_SESSIONS`
- Rankings history
- ASCII hangman rendering stored in database


## Technologies

- Oracle SQL
- PL/SQL
- Packages
- Views
- Rowtype records
- MERGE statements
- DBMS_OUTPUT


## Why build a game in PL/SQL?

PL/SQL is not a natural language for game development, which made this project an interesting constraint-based challenge.

It was created to practice:
- procedural programming
- package design
- state management
- SQL/PLSQL integration


## How to run

1. Execute `schema.sql` and `hanged_man_pkg.sql`
2. Enable server output
3. Start guessing:

```sql
CALL hanged_man_pkg.guess_letter('A');
CALL hanged_man_pkg.guess_word('METALLICA');
```

## Notes

This project was built as a learning exercise and a fun challenge to explore PL/SQL outside of standard business use cases.
