#!/bin/bash

# Test script for variable replacement functionality

echo "=== Testing Variable Replacement for Different Question Sets ==="
echo ""

# Test function for a specific question set
test_question_set() {
  local question_set=$1
  echo "--- Testing $question_set套题 ---"
  
  # Create a test JavaScript file with hardcoded values
  cat > /tmp/test_vars.js << EOF
// Mock the generateVariableContext function
function generateVariableContext(questionSet, questionIndex, studentUsername) {
  const context = {
    '{{username}}': studentUsername,
    ['{{' + questionSet + '}}']: questionSet + 'set',
    ['{{' + questionSet + (questionIndex + 1) + '}}']: questionSet + 'set_q' + (questionIndex + 1),
  };
  
  switch (questionSet) {
    case 'a':
      context['{{a_dbname}}'] = 'DAMENG';
      context['{{a_instance}}'] = 'PROD';
      context['{{a_port}}'] = '5236';
      break;
    case 'b':
      context['{{b_dbname}}'] = 'DMEXAM';
      context['{{b_instance}}'] = 'TEST';
      context['{{b_port}}'] = '5237';
      break;
  }
  
  return context;
}

// Test question content for $question_set套题
const questionContent = "请在用户 {{username}} 的机器上完成以下操作：\n1. 创建数据库 {{${question_set}_dbname}}\n2. 设置实例名 {{${question_set}_instance}}\n3. 配置端口号 {{${question_set}_port}}\n4. 验证 {{${question_set}}} 套题的变量替换";

// Generate variables
const variables = generateVariableContext('$question_set', 0, 'test_student');

// Replace variables
let processedContent = questionContent;
Object.entries(variables).forEach(([placeholder, value]) => {
  const regex = new RegExp(placeholder.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&'), 'g');
  processedContent = processedContent.replace(regex, value);
});

console.log("原始内容:");
console.log(questionContent);
console.log("\n处理后内容:");
console.log(processedContent);
console.log("\n变量映射:");
console.log(JSON.stringify(variables, null, 2));
EOF
  
  # Run the test
  node /tmp/test_vars.js
}

# Test for a套题
test_question_set "a"

# Test for b套题
echo ""
echo "="$(printf "=%.0s" {1..50})=""
echo ""
test_question_set "b"

# Clean up
rm /tmp/test_vars.js

echo ""
echo "=== Variable Replacement Test Complete ==="
