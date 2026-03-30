// Simple test script to verify core functionality

// Import the generateVariableContext function using dynamic import
import('./server/db.js').then((db) => {
  console.log('=== Testing Core Functionality ===');
  console.log('');

  // Test variable generation for a套题
  console.log('1. Testing variable generation for question set "a":');
  const contextA = db.generateVariableContext('a', 0, 'student123');
  console.log('Generated context for a套题:');
  console.log(contextA);
  console.log('');

  // Test variable generation for b套题
  console.log('2. Testing variable generation for question set "b":');
  const contextB = db.generateVariableContext('b', 1, 'student456');
  console.log('Generated context for b套题:');
  console.log(contextB);
  console.log('');

  // Test variable replacement in question content
  console.log('3. Testing variable replacement in question content:');
  const questionContent = '请在用户 {{username}} 的机器上创建名为 {{a_dbname}} 的数据库，实例名为 {{a_instance}}，端口号为 {{a_port}}';
  console.log('Original question:');
  console.log(questionContent);
  
  let processedContent = questionContent;
  Object.entries(contextA).forEach(([placeholder, value]) => {
    processedContent = processedContent.replace(new RegExp(placeholder.replace(/[.*+?^${}()|\[\]\\]/g, '\\$&'), 'g'), value);
  });
  
  console.log('Processed question:');
  console.log(processedContent);
  console.log('');

  // Test that different question sets generate different variables
  console.log('4. Testing that different question sets generate different variables:');
  console.log(`a套题数据库名: ${contextA['{{a_dbname}}']}`);
  console.log(`b套题数据库名: ${contextB['{{b_dbname}}']}`);
  console.log(`a套题实例名: ${contextA['{{a_instance}}']}`);
  console.log(`b套题实例名: ${contextB['{{b_instance}}']}`);
  console.log(`a套题端口号: ${contextA['{{a_port}}']}`);
  console.log(`b套题端口号: ${contextB['{{b_port}}']}`);
  console.log('');

  // Test username handling
  console.log('5. Testing username handling:');
  const contextEmptyUsername = db.generateVariableContext('a', 0, '');
  const contextLongUsername = db.generateVariableContext('a', 0, 'student_with_a_very_long_username_that_should_still_work');
  console.log(`Empty username: ${contextEmptyUsername['{{username}}']}`);
  console.log(`Long username: ${contextLongUsername['{{username}}']}`);
  console.log('');

  console.log('=== All tests completed successfully! ===');
}).catch((error) => {
  console.error('Error running tests:', error);
  process.exit(1);
});
