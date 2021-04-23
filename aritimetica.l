%{
#include "aritimetica.tab.h"
%}

%%

[ \t\n\r]               {}
"//".*                  { /* ignora */ }

"if"                    { return(IF);           }
"else"                  { return(ELSE);         }
"for"                   { return(FOR);          }
"do"                    { return(DO);           }
"while"                 { return(WHILE);        }

"+"                     { return '+';           }
"-"                     { return '-';           }
"*"                     { return '*';           }
"/"                     { return '/';           }
"?"                     { return '?';           }
">"                     { return '>';           }
"<"                     { return '<';           }
"||"                    { return(OR_OP);        }
"&&"                    { return(AND_OP);       }
"=="                    { return(EQ_OP);        }
"!="                    { return(NE_OP);        }
"<="			        { return(LE_OP);        }
">="			        { return(GE_OP);        }
"+="                    { return (ADD_ASSIGN);  }
"-="                    { return (SUB_ASSIGN);  }
"*="                    { return (MUL_ASSIGN);  }
";"                     { return ';';           }
"{"                     { return '{';           }
"("                     { return '(';           }
")"                     { return ')';           }
"}"                     { return '}';           }

[0-9]+ {
    /*  Coloquei aqui temporariamente enquanto ainda nao implementei INC_OP e DEC_OP
    */ 
    //usar atoi para converter de string para inteiro
    yylval.valor = atoi(yytext);
    return NUMBER;
}

[a-zA-Z_][a-zA-Z0-9_]*  {
    //o campo nome veio da declaração do tipo %union que fizemos na aritimetica.y 
    //strdup(yytext) para duplicar a string para preencher o atributo do token
    yylval.nome = strdup(yytext);
    return IDENTIFIER; 
}

.                       { return yytext[0]; }

%%