package alu_types;
  typedef enum logic [31:0] {
    ADD,
    SUBTRACT,
    MULTIPLY_LOWER,
    MULTIPLY_UPPER_UNSIGNED,
    MULTIPLY_UPPER_SIGNED,
    MULTIPLY_UPPER_SIGNED_UNSIGNED,
    DIVIDE_UNSIGNED,
    DIVIDE_SIGNED,
    REMAINDER_UNSIGNED,
    REMAINDER_SIGNED,
    AND,
    OR,
    XOR
  } alu_op_t;
endpackage
