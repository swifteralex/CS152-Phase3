%{
  #include <stdio.h>
  #include <stdlib.h>
  #include <string>
  #include <vector>
  #include <string.h>
  #include <iostream>
  #include <fstream>

  extern int currLine;
  extern int currPos;
  extern int yylex();
  extern FILE* yyin;
  std::ofstream out;
  void yyerror(const char *msg);
  int temp_counter = 0;
  int label_counter = 0;

  ////// Global variables used for inheritance or non-trivial synthesis //////
  bool identifiers_are_params;
  int param_count;
  std::vector<std::string> identifier_list;
  struct expression {
    std::string* code;
    std::string* temp;
  };
  std::vector<expression> expression_list;
  struct var {
    std::string* identifier;
    std::string* expression_code;
    std::string* expression_temp;
  };
  std::vector<var> var_list;
  ////////////////////////////////////////////////////////////////////////////
  
  enum Type { Integer, Array };
  struct Symbol {
    std::string name;
    Type type;
  };
  struct Function {
    std::string name;
    std::vector<Symbol> declarations;
  };

  std::vector <Function> symbol_table;

  Function* get_function() {
    int last = symbol_table.size()-1;
    return &symbol_table[last];
  }

  bool find(std::string& value) {
    Function* f = get_function();
    for(int i=0; i < f->declarations.size(); i++) {
      Symbol* s = &f->declarations[i];
      if (s->name == value) {
        return true;
      }
    }
    return false;
  }

  void add_function_to_symbol_table(std::string &value) {
    Function f; 
    f.name = value; 
    symbol_table.push_back(f);
  }

  void add_variable_to_symbol_table(std::string &value, Type t) {
    Symbol s;
    s.name = value;
    s.type = t;
    Function *f = get_function();
    f->declarations.push_back(s);
  }

  void print_symbol_table(void) {
    printf("symbol table:\n");
    printf("--------------------\n");
    for(int i=0; i<symbol_table.size(); i++) {
      printf("function: %s\n", symbol_table[i].name.c_str());
      for(int j=0; j<symbol_table[i].declarations.size(); j++) {
        printf("  locals: %s\n", symbol_table[i].declarations[j].name.c_str());
      }
    }
    printf("--------------------\n");
  }

  void output(std::string text) {
    std::cout << text;
    out << text;
  }

  bool is_valid_identifier_character(char c) {
          return (c == '_' || c >= '0' && c <= '9' || c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z');
  }

  void trim_identifier(std::string& identifier) {
    int index = 0;
    while (index + 1 < identifier.length() && is_valid_identifier_character(identifier[index + 1])) {
      index++;
    }
    identifier = identifier.substr(0, index + 1);
  }

  std::string get_next_temp() {
    return "temp" + std::to_string(++temp_counter);
  }

  std::string get_next_label() {
    return "label" + std::to_string(++label_counter);
  }
%}

%union{
  const char* identval;
  int numval;
  struct {
    std::string* identifier;
    std::string* expression_code;
    std::string* expression_temp;
  } var_data;
  struct {
    std::string* code;
    std::string* temp;
  } expression_data;
}

%error-verbose
%start Program
%token FUNCTION BEGIN_PARAMS END_PARAMS BEGIN_LOCALS END_LOCALS BEGIN_BODY END_BODY INTEGER ARRAY ENUM OF IF THEN ENDIF ELSE FOR WHILE DO BEGINLOOP ENDLOOP CONTINUE READ WRITE AND OR NOT TRUE FALSE RETURN SUB ADD MULT DIV MOD EQ NEQ LT GT LTE GTE SEMICOLON COLON COMMA L_PAREN R_PAREN L_SQUARE_BRACKET R_SQUARE_BRACKET ASSIGN
%token <numval> NUMBER
%token <identval> IDENT
%left L_PAREN
%left R_PAREN
%left L_SQUARE_BRACKET
%left R_SQUARE_BRACKET
%left MULT DIV
%left MOD
%left ADD SUB
%left LT
%left LTE
%left GT
%left GTE
%left EQ
%left NEQ
%right NOT
%left AND
%left OR
%right ASSIGN
%type <var_data> Var
%type <expression_data> Expression
%type <expression_data> Multiplicative-Expr
%type <expression_data> Term
%type <expression_data> Bool-Expr
%type <expression_data> Relation-Expr
%type <numval> Comp
%type <expression_data> Relation-And-Expr

%% 

Program: Program Function 
        { 
                printf("Program -> Program FUNCTION\n"); 
        }
        | /*epsilon*/ 
        { 
                printf("Program -> epsilon\n"); 
        }
        ;

Multi-Ident: Multi-Ident COMMA IDENT
        { 
                identifier_list.push_back($3);
        }
        | IDENT 
        { 
                identifier_list.push_back($1);
        }
        ;

Function: FUNCTION IDENT 
        {
                std::string str = $2; 
                add_function_to_symbol_table(str); 
                output("func " + str + "\n"); 
        } 
        SEMICOLON BEGIN_PARAMS 
        {
                identifiers_are_params = true;
                param_count = 0;
        }
        Multi-Declaration END_PARAMS BEGIN_LOCALS 
        {
                identifiers_are_params = false;
        }
        Multi-Declaration END_LOCALS BEGIN_BODY Multi-Statement END_BODY 
        { 
                std::string str = $2;
                trim_identifier(str);
                if (str != "main") {
                        output("ret 0\n");
                }
                output("endfunc\n\n"); 
        }
        ;

Declaration-Helper: Multi-Declaration {identifier_list.clear();} Multi-Ident COLON
        ;

Multi-Declaration: Declaration-Helper ENUM L_PAREN Multi-Ident R_PAREN SEMICOLON
        { 
                // TODO
        }
        | Declaration-Helper ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER SEMICOLON
        { 
                for (std::string identifier : identifier_list) {
                        add_variable_to_symbol_table(identifier, Array);
                        output(".[] " + identifier + ", " + std::to_string($4) + "\n");
                }
        }
        | Declaration-Helper INTEGER SEMICOLON
        { 
                for (std::string identifier : identifier_list) {
                        add_variable_to_symbol_table(identifier, Integer);
                        output(". " + identifier + "\n");
                        if (identifiers_are_params) { 
                                output("= " + identifier + ", $" + std::to_string(param_count++) + "\n");
                        }
                }
        }
        | /*epsilon*/
        { 
                printf("Multi-Declaration -> epsilon\n");
        }
        ;

Multi-Var: Multi-Var COMMA Var
        { 
                var new_var;
                new_var.identifier = $3.identifier;
                new_var.expression_code = $3.expression_code;
                new_var.expression_temp = $3.expression_temp;
                var_list.push_back(new_var);
        }
        | Var 
        {
                var new_var;
                new_var.identifier = $1.identifier;
                new_var.expression_code = $1.expression_code;
                new_var.expression_temp = $1.expression_temp;
                var_list.push_back(new_var);
        }
        ;

Multi-Statement: Multi-Statement Statement SEMICOLON
        {
                printf("Multi-Statement -> Statement SEMICOLON Multi-Statement\n");
        }
        | Statement SEMICOLON 
        {
                printf("Multi-Statement -> Statement SEMICOLON\n");
        }
        ;

Statement: Var ASSIGN Expression 
        {
                output(*($3.code));
                if ($1.expression_code) {
                        output(*($1.expression_code));
                        output("[]= " + *($1.identifier) + ", " + *($1.expression_temp) + ", " + *($3.temp) + "\n");
                        delete $1.expression_code;
                        delete $1.expression_temp;
                } else {
                        output("= " + *($1.identifier) + ", " + *($3.temp) + "\n");
                }
                delete $1.identifier;
                delete $3.code;
                delete $3.temp;
        }
        | IF Bool-Expr THEN Multi-Statement ENDIF 
        {
                printf("Statement -> IF Bool-Expr THEN Multi-Statement ENDIF\n");
        }
        | IF Bool-Expr THEN Multi-Statement ELSE Multi-Statement ENDIF 
        {
                printf("Statement -> IF Bool-Expr THEN Multi-Statement ELSE Multi-Statement ENDIF\n");
        }
        | WHILE Bool-Expr BEGINLOOP Multi-Statement ENDLOOP 
        {
                printf("Statement -> WHILE Bool-Expr BEGINLOOP Multi-Statement ENDLOOP\n");
        }
        | DO BEGINLOOP Multi-Statement ENDLOOP WHILE Bool-Expr 
        {      
                printf("Statement -> DO BEGINLOOP Multi-Statement ENDLOOP WHILE Bool-Expr\n");
        }
        | READ {var_list.clear();} Multi-Var 
        {
                for (var v : var_list) {
                        if (v.expression_code) {
                                output(*(v.expression_code));
                                output(".[]< " + *(v.identifier) + ", " + *(v.expression_temp) + "\n");
                                delete v.expression_code;
                                delete v.expression_temp;
                        } else {
                                output(".< " + *(v.identifier) + "\n");
                        }
                        delete v.identifier;
                }
        }
        | WRITE {var_list.clear();} Multi-Var 
        {
                for (var v : var_list) {
                        if (v.expression_code) {
                                output(*(v.expression_code));
                                output(".[]> " + *(v.identifier) + ", " + *(v.expression_temp) + "\n");
                                delete v.expression_code;
                                delete v.expression_temp;
                        } else {
                                output(".> " + *(v.identifier) + "\n");
                        }
                        delete v.identifier;
                }
        }
        | CONTINUE 
        {
                printf("Statement -> CONTINUE\n");
        }
        | RETURN Expression 
        {
                output(*($2.code));
                output("ret " + *($2.temp) + "\n");
                delete $2.code;
                delete $2.temp;
        }
        ;

Bool-Expr: Relation-And-Expr 
        {
                $$.code = $1.code;
                $$.temp = $1.temp;
        }
        | Bool-Expr OR Relation-And-Expr
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "|| " + temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;
        }
        ;

Relation-And-Expr: Relation-Expr 
        {
                $$.code = $1.code;
                $$.temp = $1.temp;
        }
        | Relation-And-Expr AND Relation-Expr 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "&& " + temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;
        }
        ;

Relation-Expr: Expression Comp Expression 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                switch ($2) {
                        case 0:
                                str += "== ";
                                break;
                        case 1:
                                str += "!= ";
                                break;
                        case 2:
                                str += "< ";
                                break;
                        case 3:
                                str += "> ";
                                break;
                        case 4:
                                str += "<= ";
                                break;
                        case 5:
                                str += ">= ";
                                break;
                }
                str += temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;  
        }
        | TRUE 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "= " + temp + "1" + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
        }
        | FALSE 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "= " + temp + "0" + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
        }
        | L_PAREN Bool-Expr R_PAREN 
        {
                $$.code = $2.code;
                $$.temp = $2.temp;
        }
        | NOT Relation-Expr
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($2.code);
                str += ". " + temp + "\n";
                str += "! " + temp + *($2.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $2.code;
                delete $2.temp;
        }
        ;

Comp: EQ 
        {
                $$ = 0;
        }
        | NEQ 
        {
                $$ = 1;
        }
        | LT 
        {
                $$ = 2;
        } 
        | GT 
        {
                $$ = 3;
        }
        | LTE 
        {
                $$ = 4;
        }
        | GTE 
        {
                $$ = 5;
        }
        ;

Multi-Expression: Multi-Expression COMMA Expression 
        {
                expression new_expression;
                new_expression.code = $3.code;
                new_expression.temp = $3.temp;
                expression_list.push_back(new_expression);
        }
        | Expression 
        {
                expression new_expression;
                new_expression.code = $1.code;
                new_expression.temp = $1.temp;
                expression_list.push_back(new_expression);
        }
        ;

Expression: Multiplicative-Expr 
        {
                $$.code = $1.code;
                $$.temp = $1.temp;
        }
        | Multiplicative-Expr ADD Expression 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "+ " + temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;
        }
        | Multiplicative-Expr SUB Expression 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "- " + temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;
        }
        ;

Multiplicative-Expr: Term 
        {
                $$.code = $1.code;
                $$.temp = $1.temp;
        }
        | Term MULT Term 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "* " + temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;
        }
        | Term DIV Term 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "/ " + temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;
        }
        | Term MOD Term 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($1.code);
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "% " + temp + ", " + *($1.temp) + ", " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $1.code;
                delete $1.temp;
                delete $3.code;
                delete $3.temp;
        }
        ;

Term: Var 
        {
                if ($1.expression_code) {
                        std::string str;
                        std::string temp = get_next_temp();
                        str += *($1.expression_code);
                        str += ". " + temp + "\n";
                        str += "=[] " + temp + ", " + *($1.identifier) + ", " + *($1.expression_temp) + "\n";
                        $$.code = new std::string(str);
                        $$.temp = new std::string(temp);
                        delete $1.expression_code;
                        delete $1.expression_temp;
                } else {
                        std::string str;
                        std::string temp = get_next_temp();
                        str += ". " + temp + "\n";
                        str += "= " + temp + ", " + *($1.identifier) + "\n";
                        $$.code = new std::string(str);
                        $$.temp = new std::string(temp);
                }
        }
        | SUB Var 
        {
                if ($2.expression_code) {
                        std::string str;
                        std::string temp = get_next_temp();
                        str += *($2.expression_code);
                        str += ". " + temp + "\n";
                        str += "=[] " + temp + ", " + *($2.identifier) + ", " + *($2.expression_temp) + "\n";
                        std::string temp2 = get_next_temp();
                        str += ". " + temp2 + "\n";
                        str += "- " + temp2 + ", 0, " + temp + "\n";
                        $$.code = new std::string(str);
                        $$.temp = new std::string(temp2);
                        delete $2.expression_code;
                        delete $2.expression_temp;
                } else {
                        std::string str;
                        std::string temp = get_next_temp();
                        str += ". " + temp + "\n";
                        str += "= " + temp + ", " + *($2.identifier) + "\n";
                        std::string temp2 = get_next_temp();
                        str += "- " + temp2 + ", 0, " + temp + "\n";
                        $$.code = new std::string(str);
                        $$.temp = new std::string(temp);
                }
        }
        | NUMBER 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "= " + temp + ", " + std::to_string($1) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
        }
        | SUB NUMBER 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "- " + temp + ", " + "0, " + std::to_string($2) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
        }
        | L_PAREN Expression R_PAREN 
        {
                $$.code = $2.code;
                $$.temp = $2.temp;
        }
        | SUB L_PAREN Expression R_PAREN 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += *($3.code);
                str += ". " + temp + "\n";
                str += "- " + temp + ", 0, " + *($3.temp) + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
                delete $3.code;
                delete $3.temp;
        }
        | IDENT L_PAREN {expression_list.clear();} Multi-Expression R_PAREN 
        {
                std::string str;
                for (expression e : expression_list) {
                        str += *(e.code);
                        str += "param " + *(e.temp) + "\n";
                        delete e.code;
                        delete e.temp;
                }
                std::string str2 = $1;
                trim_identifier(str2);
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "call " + str2 + ", " + temp + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
        }
        | IDENT L_PAREN R_PAREN 
        {
                std::string str;
                std::string str2 = $1;
                trim_identifier(str2);
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "call " + str2 + ", " + temp + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
        }
        ;

Var: IDENT 
        {
                std::string str = $1;
                trim_identifier(str);
                $$.identifier = new std::string;
                *($$.identifier) = str;
                $$.expression_code = nullptr;
                $$.expression_temp = nullptr;
        }
        | IDENT L_SQUARE_BRACKET Expression R_SQUARE_BRACKET 
        {
                std::string str = $1;
                trim_identifier(str);
                $$.identifier = new std::string;
                *($$.identifier) = str;
                $$.expression_code = $3.code;
                $$.expression_temp = $3.temp;
        }
        ;

%%

int main(int argc, char **argv) {
   out.open("output.mil");
   if (argc > 1) {
      yyin = fopen(argv[1], "r");
      if (yyin == NULL){
         printf("syntax: %s filename\n", argv[0]);
      }
   }
   yyparse();
   out.close();
   return 0;
}

void yyerror(const char *msg) {
   printf("Error at line %d, column %d: %s\n", currLine, currPos, msg);
}