/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comment_depth = 0;
%}

%x inline comment str skip

/*
 * Define names for regular expressions here.
 */

DARROW          =>
DIGIT           [0-9]
ALPNUM_         [a-zA-Z0-9_]
CAP_LETTER      [A-Z]
LOW_LETTER      [a-z]
SYN_CHARS       [\.\,\:\;\+\-\*\/\~\<\<=\=\(\)\{\}\@]


%%
 /*
  * White space
  */
\n              curr_lineno++;
[ \f\r\t\v]     ;/* Ignore white space */

 /*
  *  Nested comments
  */
--              BEGIN(inline);
<inline>.*      ; /* Ignore inline comment. */ 
<inline>\n      { BEGIN(INITIAL); curr_lineno++; }
<inline><<EOF>> BEGIN(INITIAL);

"*)"                {yylval.error_msg = "Unmatched *)"; return ERROR;}
"(*"                { BEGIN(comment); comment_depth = 1; }

<comment>"(*"       { comment_depth++; }
<comment>"*)"       {
                      comment_depth--;
                      if (!comment_depth) {
                        BEGIN(INITIAL);
                      }
                    }
<comment>\n         curr_lineno++;
<comment>[^\(\*\n]*    ;/* Eat up everything besides ( and \n. */
<comment>\([^\*\n]*   ;/* Eat up ( not followed by *. */
<comment>\*[^\*\)\n]* ;/* Eat up * not followed by ). */
<comment><<EOF>>    {
                      BEGIN(INITIAL); 
                      yylval.error_msg = "EOF in comment"; 
                      return ERROR;
                    }

 /*
  * Special syntactic symbols.
  */ 
{SYN_CHARS}     return yytext[0];

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
"<-"        { return (ASSIGN); }
"<="            return LE;

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)      return CLASS;
(?i:else)       return ELSE;
(?i:fi)         return FI;
(?i:if)         return IF;
(?i:in)         return IN;
(?i:inherits)   return INHERITS;
(?i:isvoid)     return ISVOID;
(?i:let)        return LET;
(?i:loop)       return LOOP;
(?i:pool)       return POOL;
(?i:then)       return THEN;
(?i:while)      return WHILE;
(?i:case)       return CASE;
(?i:esac)       return ESAC;
(?i:new)        return NEW;
(?i:of)         return OF;
(?i:not)        return NOT;
(t)(?i:rue)     {yylval.boolean = true; return BOOL_CONST;}
(f)(?i:alse)    {yylval.boolean = false; return BOOL_CONST;}

 /*
  * Integers, Identifiers and Special notation.
  */
{CAP_LETTER}{ALPNUM_}* {yylval.symbol = idtable.add_string(yytext); return TYPEID;}
{LOW_LETTER}{ALPNUM_}* {yylval.symbol = idtable.add_string(yytext); return OBJECTID;} 
{DIGIT}+        {
                  yylval.symbol = inttable.add_string(yytext);
                  return INT_CONST;
                }

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\"              string_buf_ptr = string_buf; BEGIN(str);

<str>\"         {
                  BEGIN(INITIAL);
                  *string_buf_ptr = '\0';
                  yylval.symbol = stringtable.add_string(string_buf);
                  return STR_CONST;
                }
<str>\n         {
                  BEGIN(INITIAL);
                  yylval.error_msg = "Unterminated string constant";
                  curr_lineno++;
                  return ERROR;
                }
<str>\0         {
                  BEGIN(skip);
                  yylval.error_msg = "String contains null character";
                }
<str><<EOF>>    {
                  BEGIN(INITIAL);
                  yylval.error_msg = "EOF in string constant";
                  return ERROR;
                }
<str>\\\0       {
                  BEGIN(skip);
                  yylval.error_msg = "String contains escaped null character";
                }
<str>\\[^btnf]  {
                  if ((string_buf_ptr - string_buf) < MAX_STR_CONST - 1) {
                    if (yytext[1] == '\n') {
                      curr_lineno++;
                    }
                    *string_buf_ptr++ = yytext[1];
                  } else {
                    BEGIN(skip);
                    yylval.error_msg = "String constant too long";
                  }
                }
<str>\\b        {
                  if ((string_buf_ptr - string_buf) < MAX_STR_CONST - 1) {
                    *string_buf_ptr++ = '\b';
                  } else {
                    BEGIN(skip);
                    yylval.error_msg = "String constant too long";
                  }
                }
<str>\\t        {
                  if ((string_buf_ptr - string_buf) < MAX_STR_CONST - 1) {
                    *string_buf_ptr++ = '\t';
                  } else {
                    BEGIN(skip);
                    yylval.error_msg = "String constant too long";
                  }
                }
<str>\\n        {
                  if ((string_buf_ptr - string_buf) < MAX_STR_CONST - 1) {
                    *string_buf_ptr++ = '\n';
                  } else {
                    BEGIN(skip);
                    yylval.error_msg = "String constant too long";
                  }
                }
<str>\\f        {
                  if ((string_buf_ptr - string_buf) < MAX_STR_CONST - 1) {
                    *string_buf_ptr++ = '\f';
                  } else {
                    BEGIN(skip);
                    yylval.error_msg = "String constant too long";
                  }
                }
<str>[^\\\n\"\0]+ {
                    char *yptr = yytext;
                    while (*yptr && (string_buf_ptr - string_buf < MAX_STR_CONST - 1)) {
                      if (string_buf_ptr - string_buf < MAX_STR_CONST - 2) {
                        *string_buf_ptr++ = *yptr++;
                      } else {
                        BEGIN(skip);
                        string_buf_ptr++;
                        yylval.error_msg = "String constant too long";
                      }
                    }
                  }

<skip>\"        {
                  BEGIN(INITIAL);
                  return ERROR;
                }
<skip>\n        {
                  BEGIN(INITIAL);
                  curr_lineno++;
                  return ERROR;
                }
<skip>\\\n      ;
<skip>[^\"\n]+  ;

  /*
   * Encounter invalid characters.
   */ 
.                 {
                    yylval.error_msg = yytext;
                    return ERROR;
                  }
%%
