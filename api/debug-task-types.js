const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function debugTaskTypes() {
  try {
    console.log('=== Debugging Task Types ===');
    
    // First, let's just get all task types
    console.log('\n1. Getting all task types...');
    const taskTypes = await prisma.taskType.findMany();
    console.log('Task types count:', taskTypes.length);
    
    taskTypes.forEach((type, index) => {
      console.log(`  ${index + 1}. ${type.name} (${type.id})`);
    });
    
    // Now let's get task type department assignments
    console.log('\n2. Getting task type department assignments...');
    const assignments = await prisma.task_type_department_assignments.findMany({
      include: {
        task_types: true,
        departments: true
      }
    });
    
    console.log('Task type assignments count:', assignments.length);
    
    assignments.forEach((assignment, index) => {
      console.log(`  Assignment ${index + 1}:`, {
        task_type: assignment.task_types.name,
        department: assignment.departments.name,
        is_origin: assignment.is_origin,
        is_destination: assignment.is_destination
      });
    });
    
  } catch (error) {
    console.error('❌ Error debugging task types:', error);
  } finally {
    await prisma.$disconnect();
  }
}

debugTaskTypes();
