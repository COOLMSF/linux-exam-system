import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { generateVariableContext } from '../server/db';

describe('Automatic Question Generation', () => {
  describe('Variable Generation', () => {
    it('should generate correct variable context for a套题', () => {
      const context = generateVariableContext('a', 0, 'student123');
      
      expect(context).toEqual({
        '{{username}}': 'student123',
        '{{a}}': 'aset',
        '{{a1}}': 'aset_q1',
        '{{a_dbname}}': 'DAMENG',
        '{{a_instance}}': 'PROD',
        '{{a_port}}': '5236',
      });
    });

    it('should generate correct variable context for b套题', () => {
      const context = generateVariableContext('b', 1, 'student456');
      
      expect(context).toEqual({
        '{{username}}': 'student456',
        '{{b}}': 'bset',
        '{{b2}}': 'bset_q2',
        '{{b_dbname}}': 'DMEXAM',
        '{{b_instance}}': 'TEST',
        '{{b_port}}': '5237',
      });
    });

    it('should handle missing username gracefully', () => {
      const context = generateVariableContext('a', 0, '');
      expect(context['{{username}}']).toBe('');
    });

    it('should handle different question indices', () => {
      const context1 = generateVariableContext('a', 0, 'student123');
      const context2 = generateVariableContext('a', 1, 'student123');
      
      expect(context1['{{a1}}']).toBe('aset_q1');
      expect(context2['{{a2}}']).toBe('aset_q2');
    });
  });

  describe('Variable Replacement', () => {
    it('should replace variables in question content correctly', () => {
      const questionContent = '请在用户 {{username}} 的机器上创建名为 {{a_dbname}} 的数据库';
      const variables = generateVariableContext('a', 0, 'student123');
      
      let processedContent = questionContent;
      Object.entries(variables).forEach(([placeholder, value]) => {
        processedContent = processedContent.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), value);
      });
      
      expect(processedContent).toBe('请在用户 student123 的机器上创建名为 DAMENG 的数据库');
    });

    it('should replace multiple variables in the same content', () => {
      const questionContent = '数据库名：{{a_dbname}}，实例名：{{a_instance}}，端口号：{{a_port}}';
      const variables = generateVariableContext('a', 0, 'student123');
      
      let processedContent = questionContent;
      Object.entries(variables).forEach(([placeholder, value]) => {
        processedContent = processedContent.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), value);
      });
      
      expect(processedContent).toBe('数据库名：DAMENG，实例名：PROD，端口号：5236');
    });

    it('should handle variables that are not present in the content', () => {
      const questionContent = '只有 {{username}} 变量';
      const variables = generateVariableContext('a', 0, 'student123');
      
      let processedContent = questionContent;
      Object.entries(variables).forEach(([placeholder, value]) => {
        processedContent = processedContent.replace(new RegExp(placeholder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), value);
      });
      
      expect(processedContent).toBe('只有 student123 变量');
    });
  });

  describe('Question Set Differentiation', () => {
    it('should generate different contexts for different question sets', () => {
      const contextA = generateVariableContext('a', 0, 'student123');
      const contextB = generateVariableContext('b', 0, 'student123');
      
      expect(contextA['{{a_dbname}}']).toBe('DAMENG');
      expect(contextB['{{b_dbname}}']).toBe('DMEXAM');
      expect(contextA['{{a_instance}}']).toBe('PROD');
      expect(contextB['{{b_instance}}']).toBe('TEST');
    });

    it('should generate different question-specific variables for same set', () => {
      const context1 = generateVariableContext('a', 0, 'student123');
      const context2 = generateVariableContext('a', 1, 'student123');
      
      expect(context1['{{a1}}']).toBe('aset_q1');
      expect(context2['{{a2}}']).toBe('aset_q2');
    });
  });

  describe('Username Handling', () => {
    it('should use provided username in variable context', () => {
      const context = generateVariableContext('a', 0, 'custom_user');
      expect(context['{{username}}']).toBe('custom_user');
    });

    it('should handle empty username', () => {
      const context = generateVariableContext('a', 0, '');
      expect(context['{{username}}']).toBe('');
    });

    it('should handle long username', () => {
      const longUsername = 'student_with_a_very_long_username_that_should_still_work';
      const context = generateVariableContext('a', 0, longUsername);
      expect(context['{{username}}']).toBe(longUsername);
    });
  });
});
