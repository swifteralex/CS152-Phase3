%{
  #include <stdio.h>
  #include <stdlib.h>
  #include <string>
  #include <vector>
  #include <string.h>
  #include <iostream>
  #include <fstream>
  #include <stack>

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
  std::stack<std::vector<std::string*>> statement_list;
  std::string* read_statement_list() {
    std::string str;
    std::vector<std::string*> top = statement_list.top();
    for (std::string* statement : top) {
      str += (*statement);
      delete statement;
    }
    statement_list.pop();
    return new std::string(str);
  }
  std::stack<std::string> loop_begin_labels;
  ////////////////////////////////////////////////////////////////////////////
  
  struct Symbol {
    Symbol(std::string identifier, std::string type) : identifier(identifier), type(type) {}
    std::string identifier;
    std::string type;
  };
  std::vector<Symbol> symbol_table;

  bool find_symbol(std::string& value) {
    for (Symbol s : symbol_table) {
      if (s.identifier == value) {
        return true;
      }
    }
    return false;
  }

  std::string find_symbol_type(std::string& value) {
    for (Symbol s : symbol_table) {
      if (s.identifier == value) {
        return s.type;
      }
    }
    return "no_match";
  }

  void add_to_symbol_table(Symbol& value) {
    symbol_table.push_back(value);
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
  struct {
    std::string* code;
  } statement_data;
  struct {
    std::string* statement_code;
    std::string* expression_code;
    std::string* expression_temp;
  } if_helper_data;
}

%error-verbose
%start Start-Program
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
%type <statement_data> Statement
%type <statement_data> Multi-Statement
%type <if_helper_data> If-Helper

%% 

Start-Program: Program 
        {
                std::string str = "main";
                if (!find_symbol(str)) {
                        printf("Error: no main function defined\n");
                        exit(1);
                }
        }
        | 
        %empty 
        {
                output("func main\n");
                output("endfunc\n");
        }
        ;

Program: Program Function 
        | Function
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
                Symbol s(str, "function");
                add_to_symbol_table(s); 
                output("func " + str + "\n"); 
        } 
        SEMICOLON BEGIN_PARAMS {identifiers_are_params = true; param_count = 0;} Multi-Declaration END_PARAMS BEGIN_LOCALS {identifiers_are_params = false;}
        Multi-Declaration END_LOCALS BEGIN_BODY {std::vector<std::string*> list; statement_list.push(list);} Multi-Statement {$15.code = read_statement_list();} END_BODY 
        { 
                output(*($15.code));
                delete $15.code;
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

Multi-Declaration: Declaration-Helper 
        {
                for (std::string identifier : identifier_list) {
                        if (identifier == "miniL") {
                                std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": can't have variable with same name as program\n";
                                printf(error.c_str());
                                exit(1);
                        }
                        if (find_symbol(identifier)) {
                                std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": multiple declarations of variable \"" + identifier + "\"\n";
                                printf(error.c_str());
                                exit(1);
                        }
                        Symbol s(identifier, "integer");
                        add_to_symbol_table(s);
                        output(". " + identifier + "\n");
                }
        }
        ENUM L_PAREN {identifier_list.clear();} Multi-Ident R_PAREN SEMICOLON
        { 
                for (int i = 0; i < identifier_list.size(); i++) {
                        std::string identifier = identifier_list[i];
                        output(". " + identifier + "\n");
                        output("= " + identifier + ", " + std::to_string(i) + "\n");
                }
        }
        | Declaration-Helper ARRAY L_SQUARE_BRACKET NUMBER R_SQUARE_BRACKET OF INTEGER SEMICOLON
        { 
                for (std::string identifier : identifier_list) {
                        if (identifier == "miniL") {
                                std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": can't have variable with same name as program\n";
                                printf(error.c_str());
                                exit(1);
                        }
                        if (find_symbol(identifier)) {
                                std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": multiple declarations of variable \"" + identifier + "\"\n";
                                printf(error.c_str());
                                exit(1);
                        }
                        if ($4 == 0) {
                                std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": cannot have array of size 0\n";
                                printf(error.c_str());
                                exit(1);
                        }
                        Symbol s(identifier, "array");
                        add_to_symbol_table(s);
                        output(".[] " + identifier + ", " + std::to_string($4) + "\n");
                }
        }
        | Declaration-Helper INTEGER SEMICOLON
        { 
                for (std::string identifier : identifier_list) {
                        if (identifier == "miniL") {
                                std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": can't have variable with same name as program\n";
                                printf(error.c_str());
                                exit(1);
                        }
                        if (find_symbol(identifier)) {
                                std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": multiple declarations of variable \"" + identifier + "\"\n";
                                printf(error.c_str());
                                exit(1);
                        }
                        Symbol s(identifier, "integer");
                        add_to_symbol_table(s);
                        output(". " + identifier + "\n");
                        if (identifiers_are_params) { 
                                output("= " + identifier + ", $" + std::to_string(param_count++) + "\n");
                        }
                }
        }
        | %empty
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
                statement_list.top().push_back($2.code);
        }
        | Statement SEMICOLON 
        {
                statement_list.top().push_back($1.code);
        }
        ;

If-Helper: IF Bool-Expr THEN {std::vector<std::string*> list; statement_list.push(list);} Multi-Statement 
        {
                $5.code = read_statement_list();
                $$.statement_code = $5.code;
                $$.expression_code = $2.code;
                $$.expression_temp = $2.temp;
        }
        ;

Statement: Var ASSIGN Expression 
        {
                std::string str;
                str += *($3.code);
                if ($1.expression_code) {
                        str += *($1.expression_code);
                        str += "[]= " + *($1.identifier) + ", " + *($1.expression_temp) + ", " + *($3.temp) + "\n";
                        delete $1.expression_code;
                        delete $1.expression_temp;
                } else {
                        str += "= " + *($1.identifier) + ", " + *($3.temp) + "\n";
                }
                $$.code = new std::string(str);
                delete $1.identifier;
                delete $3.code;
                delete $3.temp;
        }
        | If-Helper ENDIF 
        {
                std::string str;
                std::string true_label = get_next_label();
                std::string false_label = get_next_label();
                str += *($1.expression_code);
                str += "?:= " + true_label + ", " + *($1.expression_temp) + "\n";
                str += ":= " + false_label + "\n";
                str += ": " + true_label + "\n";
                str += *($1.statement_code);
                str += ": " + false_label + "\n";
                $$.code = new std::string(str);
                delete $1.statement_code;
                delete $1.expression_code;
                delete $1.expression_temp;
        }
        | If-Helper ELSE {std::vector<std::string*> list; statement_list.push(list);} Multi-Statement {$4.code = read_statement_list();} ENDIF 
        {
                std::string str;
                std::string true_label = get_next_label();
                std::string false_label = get_next_label();
                std::string end_label = get_next_label();
                str += *($1.expression_code);
                str += "?:= " + true_label + ", " + *($1.expression_temp) + "\n";
                str += ":= " + false_label + "\n";
                str += ": " + true_label + "\n";
                str += *($1.statement_code);
                str += ":= " + end_label + "\n";
                str += ": " + false_label + "\n";
                str += *($4.code);
                str += ": " + end_label + "\n";
                $$.code = new std::string(str);
                delete $1.statement_code;
                delete $1.expression_code;
                delete $1.expression_temp;
                delete $4.code;
        }
        | WHILE Bool-Expr BEGINLOOP {std::vector<std::string*> list; statement_list.push(list); loop_begin_labels.push(get_next_label());} Multi-Statement {$5.code = read_statement_list();} ENDLOOP 
        {
                std::string str;
                std::string end_label = get_next_label();
                std::string true_label = get_next_label();
                std::string begin_label = loop_begin_labels.top();
                loop_begin_labels.pop();
                str += ": " + begin_label + "\n";
                str += *($2.code);
                str += "?:= " + true_label + ", " + *($2.temp) + "\n";
                str += ":= " + end_label + "\n";
                str += ": " + true_label + "\n";
                str += *($5.code);
                str += ":= " + begin_label + "\n";
                str += ": " + end_label + "\n";
                $$.code = new std::string(str);
                delete $2.code;
                delete $2.temp;
                delete $5.code;
        }
        | DO BEGINLOOP {std::vector<std::string*> list; statement_list.push(list); loop_begin_labels.push(get_next_label());} Multi-Statement {$4.code = read_statement_list();} ENDLOOP WHILE Bool-Expr 
        {
                std::string str;
                std::string begin_label = get_next_label();
                std::string continue_label = loop_begin_labels.top();
                loop_begin_labels.pop();
                str += ": " + begin_label + "\n";
                str += *($4.code);
                str += ": " + continue_label + "\n";
                str += *($8.code);
                str += "?:= " + begin_label + ", " + *($8.temp) + "\n";
                $$.code = new std::string(str);
                delete $8.code;
                delete $8.temp;
                delete $4.code;
        }
        | READ {var_list.clear();} Multi-Var 
        {
                std::string str;
                for (var v : var_list) {
                        if (v.expression_code) {
                                str += *(v.expression_code);
                                str += ".[]< " + *(v.identifier) + ", " + *(v.expression_temp) + "\n";
                                delete v.expression_code;
                                delete v.expression_temp;
                        } else {
                                str += ".< " + *(v.identifier) + "\n";
                        }
                        delete v.identifier;
                }
                $$.code = new std::string(str);
        }
        | WRITE {var_list.clear();} Multi-Var 
        {
                std::string str;
                for (var v : var_list) {
                        if (v.expression_code) {
                                str += *(v.expression_code);
                                str += ".[]> " + *(v.identifier) + ", " + *(v.expression_temp) + "\n";
                                delete v.expression_code;
                                delete v.expression_temp;
                        } else {
                                str += ".> " + *(v.identifier) + "\n";
                        }
                        delete v.identifier;
                }
                $$.code = new std::string(str);
        }
        | CONTINUE 
        {
                if (loop_begin_labels.size() == 0) {
                        std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": use of \"continue\" while outside a loop\n";
                        printf(error.c_str());
                        exit(1);
                }
                std::string str;
                std::string begin_label = loop_begin_labels.top();
                str += ":= " + begin_label + "\n";
                $$.code = new std::string(str);
        }
        | RETURN Expression 
        {
                std::string str;
                str += *($2.code);
                str += "ret " + *($2.temp) + "\n";
                delete $2.code;
                delete $2.temp;
                $$.code = new std::string(str);
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
                str += "= " + temp + ", 1" + "\n";
                $$.code = new std::string(str);
                $$.temp = new std::string(temp);
        }
        | FALSE 
        {
                std::string str;
                std::string temp = get_next_temp();
                str += ". " + temp + "\n";
                str += "= " + temp + ", 0" + "\n";
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
                str += "! " + temp + ", " + *($2.temp) + "\n";
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
                if (!find_symbol(str2)) {
                        std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": use of undeclared function \"" + str2 + "\"\n";
                        printf(error.c_str());
                        exit(1);
                }
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
                if (!find_symbol(str2)) {
                        std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": use of undeclared function \"" + str2 + "\"\n";
                        printf(error.c_str());
                        exit(1);
                }
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
                if (!find_symbol(str)) {
                        std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": use of undeclared variable \"" + str + "\"\n";
                        printf(error.c_str());
                        exit(1);
                }
                if (find_symbol_type(str) == "array") {
                        std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": array variable \"" + str + "\" used without index\n";
                        printf(error.c_str());
                        exit(1);
                }
                $$.identifier = new std::string;
                *($$.identifier) = str;
                $$.expression_code = nullptr;
                $$.expression_temp = nullptr;
        }
        | IDENT L_SQUARE_BRACKET Expression R_SQUARE_BRACKET 
        {
                std::string str = $1;
                trim_identifier(str);
                if (!find_symbol(str)) {
                        std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": use of undeclared variable \"" + str + "\"\n";
                        printf(error.c_str());
                        exit(1);
                }
                if (find_symbol_type(str) == "integer") {
                        std::string error = "Error at line " + std::to_string(currLine) + ", column " + std::to_string(currPos) + ": attempt to index integer variable \"" + str + "\"\n";
                        printf(error.c_str());
                        exit(1);
                }
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