// Test script for variable replacement functionality
console.log("=== Testing Variable Replacement for Different Question Sets ===");
console.log("");

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

// Test function for a specific question set
function testQuestionSet(questionSet) {
  console.log(`--- Testing ${questionSet}套题 ---`);
  
  // Test question content
  const questionContent = `请在用户 {{username}} 的机器上完成以下操作：
1. 创建数据库 {{${questionSet}_dbname}}
2. 设置实例名 {{${questionSet}_instance}}
3. 配置端口号 {{${questionSet}_port}}
4. 验证 {{${questionSet}}} 套题的变量替换`;
  
  // Generate variables
  const variables = generateVariableContext(questionSet, 0, 'test_student');
  
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
}

// Test for a套题
testQuestionSet("a");

// Test for b套题
console.log("");
console.log("=" + "=".repeat(50) + "=");
console.log("");
testQuestionSet("b");

console.log("");
console.log("=== Variable Replacement Test Complete ===");
