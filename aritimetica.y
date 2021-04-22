
%{
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>

int yyerror(const char *s);
int yylex(void);
int errorc = 0;

enum sno_type { NO_GENERIC, NO_STMTS, NO_ATTRIB, NO_GETVAR,
NO_CONST, NO_BINARY_OPER, NO_IF_SELECTION, NO_IF_ELSE_SELECTION,
NO_WHILE_ITERATION, NO_DO_WHILE_ITERATION, NO_FOR_ITERATION };

typedef struct {
    char *nome;
    bool exists;
    int token;
} simbolo;

//estrutura nó da nossa árvore
struct syntaticno {
    //para cada nó ter um ID
    int id;

    //para dar nome ao nó
    char *label;

    //simbolo que está presente na tabela de simbolo
    simbolo *sim;

    enum sno_type type;
    int constValue;
    int qtdFilhos;
    bool declara_var;

    //parte recursiva para criar estruturas dinâmicas evitando o uso de alocamento da linguagem C
    struct syntaticno *filhos[1];
};
typedef struct syntaticno syntaticno;

//Padrão visitor, mas em C
//O typedef define um tipo de ação para o visitante
typedef void (*visitor_action)(syntaticno **root, syntaticno *no);
void visitor_leaf_first(syntaticno **root, visitor_action act);
void check_declared_vars(syntaticno **root, syntaticno *no);
void collapse_stmts(syntaticno **root, syntaticno *no);

//Para contar a quantidade de simbolos no vetor tsimbolos
int simbolo_qtd = 0;
//declara nosso vetor do tipo struct simbolo com 100 posições, ou seja, 100 variáveis no maximo para usarmos no programa
simbolo tsimbolos[100];
//Variavel auxiliar para ajudar a criar mais simbolos 
simbolo *simbolo_novo(char *nome, int token);
//Variavel auxiliar para ajudar a verificar a existencia de simbolos no nosso vetor
simbolo *simbolo_existe(char *nome);
syntaticno *novo_syntaticno(char *label, int filhos);
void debug(syntaticno *root);
void translate(syntaticno *root);

%}

/* atributos dos tokens */
%union {
    char *nome;
    int valor;
    struct syntaticno *no;
}

%define parse.error verbose

%token NUMBER IDENTIFIER
%token IF ELSE FOR DO WHILE
%token AND_OP OR_OP EQ_OP NE_OP

//O tipo do token IDENTIFIER é o campo nome, ou seja, o atributo do token IDENTIFIER é o campo nome da %union criada nas linhas acima
%type <nome> IDENTIFIER
%type <valor> NUMBER
%type <no> PROGRAM ARITHMETIC EXPRESSION TERM FACTOR STMTS STMT
%type <no> SELECT_STMT ITERATION_STMT

%start PROGRAM

%%

PROGRAM 
        : STMTS { 
            if(errorc > 0)
                printf("%d erro(s) encontrados\n", errorc);
            else{
                printf("*------------------------------------*\n");
                printf(" Programa reconhecido sintaticamente!\n");
                printf("*------------------------------------*\n");
                syntaticno *root = novo_syntaticno("prog", 1);
                root->filhos[0] = $1;
                
                // analise semantica
                //essa função irá visitar e percorrer a arvore
                visitor_leaf_first(&root, collapse_stmts);
                visitor_leaf_first(&root, check_declared_vars);
                debug(root);
                translate(root);
            }
        }
;
    
STMTS 
        : STMT STMTS {
            $$ = novo_syntaticno("stmts", 2);
            $$->type = NO_STMTS;
            $$->filhos[0] = $1;
            $$->filhos[1] = $2;
        }

        | STMT { $$ = $1; }
;

//Aqui pode se colocar novas funções, declaração de funções, e dentro dessas funções criar novos comandos como if, loop etc
STMT 
        : IDENTIFIER '=' ARITHMETIC {
            simbolo *s = simbolo_existe($1);
            if(!s)
                s = simbolo_novo($1, IDENTIFIER);
            
            syntaticno *nv = novo_syntaticno($1, 0);
            nv->sim = s;
            $$ = novo_syntaticno("=", 2);
            $$->filhos[0] = nv;
            $$->filhos[1] = $3;
            $$->type = NO_ATTRIB;
        }

        | SELECT_STMT

        | ITERATION_STMT

;

SELECT_STMT 
        : IF '(' EXPRESSION  ')' '{' STMT '}' {
            /*
             * cria nó identificando o bloco com "if"
            */
            $$ = novo_syntaticno("if_block", 2);
            $$->type = NO_IF_SELECTION;

            /*
             * cria nó identificando o bloco com a condicao logica para o "if"
            */
            syntaticno *s_condicao_logica = novo_syntaticno("condicao_logica", 1);
            s_condicao_logica->filhos[0] = $3;
            $$->filhos[0] = s_condicao_logica;
                
            syntaticno *s_if_stmts = novo_syntaticno("if_stmts", 1);
            s_if_stmts->filhos[0] = $6;
            $$->filhos[1] = s_if_stmts;
        }

        | IF '(' EXPRESSION  ')' '{' STMT '}' ELSE '{' STMT '}' {
            /*
             * cria nó identificando o bloco com "if" {} "else" {}
            */
            $$ = novo_syntaticno("if_else_block", 3);
            $$->type = NO_IF_ELSE_SELECTION;

            /*
             * cria nó identificando o bloco com a condicao logica do "if"
            */
            syntaticno *s_condicao_logica = novo_syntaticno("condicao_logica", 1);
            s_condicao_logica->filhos[0] = $3;
            $$->filhos[0] = s_condicao_logica;

            /*
             * cria nó identificando o bloco com o statement para o "if"
            */
            syntaticno *s_if_stmts = novo_syntaticno("if_stmts", 1);
            s_if_stmts->filhos[0] = $6;
            $$->filhos[1] = s_if_stmts;

            /*
             * cria nó identificando o bloco com o statement para o "else"
            */
            syntaticno *s_else_stmts = novo_syntaticno("else_stmts", 1);
            s_else_stmts->filhos[0] = $10;
            $$->filhos[2] = s_else_stmts;
        }
;

ITERATION_STMT 
        : WHILE '(' EXPRESSION ')' '{' STMT '}' {
            /*
             * cria nó identificando o bloco com "while () {}"
            */
            $$ = novo_syntaticno("while_block", 2);
            $$->type = NO_WHILE_ITERATION;
            $$->filhos[0] = $3;
            $$->filhos[1] = $6;
        } 

        | DO '{' STMT '}' WHILE '(' EXPRESSION ')' {
            /*
             * cria nó identificando o bloco com "do {} while ();"
            */
            $$ = novo_syntaticno("do_while_block", 2);
            $$->type = NO_DO_WHILE_ITERATION;
            $$->filhos[0] = $3;
            $$->filhos[1] = $7;
        }

        | FOR '(' EXPRESSION ';' EXPRESSION ';' EXPRESSION ')' '{' STMT '}' {
            /*
             * cria nó identificando o bloco com "for () {}"
            */$$ = novo_syntaticno("for_block", 4);
            $$->type = NO_FOR_ITERATION;
            $$->filhos[0] = $3;
            $$->filhos[1] = $5;
            $$->filhos[2] = $7;
            $$->filhos[3] = $10;
        }
;

ARITHMETIC 
        : EXPRESSION { $$ = $1; }
        | EXPRESSION error
;

/*
    $$->type = NO_BINARY_OPER seta a regra como uma operação binária
*/
EXPRESSION 
        : EXPRESSION '+' TERM {
            // $1 é EXPRESSION e $3 é TERM
            $$ = novo_syntaticno("+", 2);
            $$->type = NO_BINARY_OPER;
            $$->filhos[0] = $1;
            $$->filhos[1] = $3;
        }

        | EXPRESSION '-' TERM {
            // $1 é EXPRESSION e $3 é TERM
            $$ = novo_syntaticno("-", 2);
            $$->type = NO_BINARY_OPER;
            $$->filhos[0] = $1;
            $$->filhos[1] = $3;
        }

        | EXPRESSION OR_OP TERM {
           $$ = novo_syntaticno("||", 2);
           $$->type = NO_BINARY_OPER;
           $$->filhos[0] = $1;
           $$->filhos[1] = $3;
        }

        | EXPRESSION AND_OP TERM {
           $$ = novo_syntaticno("&&", 2);
           $$->type = NO_BINARY_OPER;
           $$->filhos[0] = $1;
           $$->filhos[1] = $3;
        }

        | EXPRESSION EQ_OP TERM {
           $$ = novo_syntaticno("==", 2);
           $$->type = NO_BINARY_OPER;
           $$->filhos[0] = $1;
           $$->filhos[1] = $3;
        }

        | EXPRESSION NE_OP TERM {
           $$ = novo_syntaticno("!=", 2);
           $$->type = NO_BINARY_OPER;
           $$->filhos[0] = $1;
           $$->filhos[1] = $3;
        }

        | TERM { $$ = $1; }
;

TERM 
        : TERM '*' FACTOR {
            // $1 é TERM e $3 é FACTOR
            $$ = novo_syntaticno("*", 2);
            $$->type = NO_BINARY_OPER;
            $$->filhos[0] = $1;
            $$->filhos[1] = $3;
        }

        | TERM '/' FACTOR {
            // $1 é TERM e $3 é FACTOR
            $$ = novo_syntaticno("/", 2);
            $$->type = NO_BINARY_OPER;
            $$->filhos[0] = $1;
            $$->filhos[1] = $3;
        }

        | FACTOR { $$ = $1; }
;

FACTOR 
        : '(' EXPRESSION ')' {
            // $$ = novo_syntaticno("()", 1);
            //$$->filhos[0] = $2;
            //Podemos descartar os parenteses durante o processo de compilação
            //ao invés de adicionar os parenteses na árvore, vamos
            //adicionar ao codigo durante a compilação na função translate_tree()
            $$ = $2;
        }

        | NUMBER {
           $$ = novo_syntaticno("const", 0);
           $$->constValue = $1;
           $$->type = NO_CONST;
        }

        | IDENTIFIER {
            /*
                O $1 significa que é o primeiro argumento da regra, ou seja,
                o campo IDENTIFIER nesse caso.
                Se fosse uma regra com 3 campos, por exemplo IDENTIFIER '+' FACTOR,
                teriamos 3 argumentos: $1, $2 e $3 respectivamente.
                Aqui vamos retornar os nós de árvore em cada regra
            */
            simbolo *s = simbolo_existe($1);
            if(!s)
                s = simbolo_novo($1, IDENTIFIER);
            //retorna o nó para a variavel que foi expandida e que chamou o IDENTIFIER, o valor 0 significa que ele nao tem filhos na folha 
            $$ = novo_syntaticno("IDENTIFIER", 0);
            $$->type = NO_GETVAR;
            $$->sim = s;
        }

;

%%

int yywrap(){
    return 1;
}

int yyerror(const char *s){
    errorc++;
    printf("erro %d: %s\n", errorc, s);
    return 1;
}

simbolo *simbolo_novo(char *nome, int token){
    tsimbolos[simbolo_qtd].nome = nome;
    tsimbolos[simbolo_qtd].token = token;
    tsimbolos[simbolo_qtd].exists = false;
    simbolo *result = &tsimbolos[simbolo_qtd];
    simbolo_qtd++;
    return result;
}

simbolo *simbolo_existe(char *nome){
    //busca linear usando comparação de strings
    for(int i = 0; i < simbolo_qtd; i++){
        if(strcmp(tsimbolos[i].nome, nome) == 0)
            return &tsimbolos[i];
    }
    return NULL;
}

syntaticno *novo_syntaticno(char *label, int filhos) {
    static int nid = 0;
    //para saber a quantidade de filhos do nó 
    int s = sizeof(syntaticno);
    
    if (filhos > 1){
        s += sizeof(syntaticno*) * (filhos-1);
    }

    syntaticno *n = (syntaticno*) calloc(1, s);
    n->id = nid++;
    n->label = label;
    n->qtdFilhos = filhos;
    n->type = NO_GENERIC;
    n->declara_var = false;
    return n;
}

void print_tree(syntaticno *n){
    if (n->sim)
        printf("\tn%d [label=\"%s\"];\n", n->id, n->sim->nome);
    else if (strcmp(n->label, "const") == 0)
        printf("\tn%d [label=\"%d\"];\n", n->id, n->constValue);
    else
        printf("\tn%d [label=\"%s\"];\n", n->id, n->label);
        
    for(int i = 0; i < n->qtdFilhos; i++)
        print_tree(n->filhos[i]);
    for(int i = 0; i < n->qtdFilhos; i++)
        printf("\tn%d -- n%d\n", n->id, n->filhos[i]->id);
}

//Traduzindo entrada para codigo em C nesse exemplo
void translate_tree(syntaticno *no){

    switch(no->type){
        case NO_ATTRIB:
            if (no->declara_var)
                printf("\tvar %s = ", no->filhos[0]->sim->nome);
            else
                printf("\t %s = ", no->filhos[0]->sim->nome);
            
            for(int i = 1; i < no->qtdFilhos; i++)
                translate_tree(no->filhos[i]);

            printf(";\n");
            break;
        
        case NO_GETVAR:
            printf(" %s ", no->sim->nome);
            break;

        case NO_CONST:
            printf(" %d ", no->constValue);
            break;

        case NO_BINARY_OPER:
            //imprime em ordem esquerda -> raiz -> direita
            printf("(");
            translate_tree(no->filhos[0]);
            printf(" %s ", no->label);
            translate_tree(no->filhos[1]);
            printf(")");
            break;

        case NO_IF_SELECTION:
            printf("\n\tif ");
            translate_tree(no->filhos[0]);
            printf(" {\n\t");
            translate_tree(no->filhos[1]);
            printf("\t}\n");
            break;

        case NO_IF_ELSE_SELECTION:
            printf("\n\tif ");
            translate_tree(no->filhos[0]);
            printf(" {\n\t");
            translate_tree(no->filhos[1]);
            printf("\t} else {\n\t");
            translate_tree(no->filhos[2]);
            printf("\t}\n");
            break;

        case NO_WHILE_ITERATION:
            printf("\n\twhile ");
            translate_tree(no->filhos[0]);
            printf(" {\n\t");
            translate_tree(no->filhos[1]);
            printf("\n\t}\n");
            break;

        case NO_DO_WHILE_ITERATION:
            printf("\n\tdo {\n\t");
            //Entra no nó à esquerda, no caso é o STMT
            translate_tree(no->filhos[0]);
            printf("\t} while ");
            //Entra no nó à direita, no caso é o EXPRESSION
            translate_tree(no->filhos[1]);
            printf(";\n");
            break;

        default:
            for(int i = 0; i < no->qtdFilhos; i++)
                translate_tree(no->filhos[i]);
            break;
    }

    //função para tratar a raiz
}

void translate(syntaticno *no){
    //Aqui traduzo a entrada para linguagem Dart
    printf("void main(){\n");
    
    //vai percorrer a arvore formato esquerda -> direia -> raiz e vai imprimir o codigo dentro da função main()
    translate_tree(no);
    
    printf("\n}\n");
}

//Função que irá percorrer a tabela de simbolos e imprimir os encontrados
void debug(syntaticno *no){
    printf("Simbolos: \n");
    for(int i = 0; i < simbolo_qtd; i++){
        printf("\t%s\n", tsimbolos[i].nome);
    }
    /* graph prog { ... } */
    printf("AST: \n");
    printf("graph prog {\n");
    print_tree(no);
    printf("}\n");
}

void visitor_leaf_first(syntaticno **root, visitor_action act){
    syntaticno *r = *root;
    for(int i = 0; i < r->qtdFilhos; i++){
        visitor_leaf_first(&r->filhos[i], act);
        if (act)
            act(root, r->filhos[i]);
    }
}

void collapse_stmts(syntaticno **root, syntaticno *no){
    syntaticno *r = *root;

    if(r->type == NO_STMTS && no->type == NO_STMTS) {
        int nsize = sizeof(syntaticno);
        nsize += sizeof(syntaticno*) * (r->qtdFilhos-1); 
        nsize += sizeof(syntaticno*) * (no->qtdFilhos-1);

        r = *root = realloc(*root, nsize);
        r->qtdFilhos--;
        for(int i = 0; i < no->qtdFilhos; i++){
            r->filhos[r->qtdFilhos] = no->filhos[i];
            r->qtdFilhos++;
        }

        free(no);
    }
}

void check_declared_vars(syntaticno **root, syntaticno *no){
    syntaticno *r = *root;

    if(no->type == NO_ATTRIB){
        simbolo *s = no->filhos[0]->sim;
        if(!s->exists){
            s->exists = true;
            no->declara_var = true;
        }
    }
    else if(no->type == NO_GETVAR){
        if(!no->sim->exists){
            printf("erro: variavel %s nao declarada \n", no->sim->nome);
            errorc++;
        }
    }
}

int main(int argc, char *argv[]){

    extern FILE *yyin;
    if(argc > 1)
        yyin = fopen(argv[1], "r");

    yyparse();

    if (yyin)
        fclose(yyin);
}