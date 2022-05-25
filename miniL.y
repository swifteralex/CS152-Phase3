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

  // Global variables used for inheritance or non-trivial synthesis
  bool identifiers_are_params;
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

Multi-Declaration: Multi-Declaration {identifier_list.clear();} Declaration SEMICOLON
        { 
                printf("Multi-Declaration -> Declaration SEMICOLON Multi-Declaration\n");
        }
        | /*epsilon*/
        { 
                printf("Multi-Declaration -> epsilon\n");
        }
        ;

Function: FUNCTION IDENT 
        {
                std::string str = $2; add_function_to_symbol_table(str); output("func " + str + "\n"); print_symbol_table();
        } 
        SEMICOLON BEGIN_PARAMS 
        {
                identifiers_are_params = true;
        }
        Multi-Declaration END_PARAMS BEGIN_LOCALS 
        {
                identifiers_are_params = false;
        }
        Multi-Declaration END_LOCALS BEGIN_BODY Multi-Statement END_BODY 
        { 
                output("endfunc\n\n"); 
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

Declaration: Multi-Ident COLON ENUM L_PAREN Multi-Ident R_PAREN
        { 
                // TODO
        }
        | Multi-Ident COLON ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER 
        { 
                for (int i = 0; i < identifier_list.size(); i++) {
                        std::string identifier = identifier_list[i];
                        add_variable_to_symbol_table(identifier, Array);
                        output(".[] " + identifier + ", " + std::to_string($5) + "\n");
                }
        }
        | Multi-Ident COLON INTEGER 
        { 
                for (int i = 0; i < identifier_list.size(); i++) {
                        std::string identifier = identifier_list[i];
                        add_variable_to_symbol_table(identifier, Integer);
                        output(". " + identifier + "\n");
                        if (identifiers_are_params) { 
                                output("= " + identifier + ", $" + std::to_string(i) + "\n");
                        }
                }
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
                output("= " + *($1.identifier) + ", " + *($3.temp) + "\n");
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
        | READ Multi-Var 
        {
                printf("Statement -> READ Multi-Var\n");
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
                printf("Statement -> RETURN Expression\n");
        }
        ;

Bool-Expr: Relation-And-Expr 
        {
                printf("Bool-Expr -> Relation-And-Expr\n");
        }
        | Relation-And-Expr OR Bool-Expr 
        {
                printf("Bool-Expr -> Relation-And-Expr OR Bool-Expr\n");
        }
        ;

Relation-And-Expr: Relation-Expr 
        {
                printf("Relation-And-Expr -> Relation-Expr\n");
        }
        | Relation-Expr AND Relation-And-Expr 
        {
                printf("Relation-And-Expr -> Relation-Expr AND Relation-And-Expr\n");
        }
        ;

Relation-Expr: Expression Comp Expression 
        {
                printf("Relation-Expr -> Expression Comp Expression\n");
        }
        | TRUE 
        {
                printf("Relation-Expr -> TRUE\n");
        }
        | FALSE 
        {
                printf("Relation-Expr -> FALSE\n");
        }
        | L_PAREN Bool-Expr R_PAREN 
        {
                printf("Relation-Expr -> L_PAREN Bool-Expr R_PAREN\n");
        }
        | NOT Relation-Expr
        {
                printf("Relation-Expr -> NOT Relation-Expr\n");
        }
        ;

Comp: EQ 
        {
                printf("Comp -> EQ\n");
        }
        | NEQ 
        {
                printf("Comp -> NEQ\n");
        }
        | LT 
        {
                printf("Comp -> LT\n");
        } 
        | GT 
        {
                printf("Comp -> GT\n");
        }
        | LTE 
        {
                printf("Comp -> LTE\n");
        }
        | GTE 
        {
                printf("Comp -> GTE\n");
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
                str += "= " + temp + ", " + std::to_string(-$2) + "\n";
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
                std::string str = $1;
                trim_identifier(str);
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "call " + str + ", " + temp + "\n";
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