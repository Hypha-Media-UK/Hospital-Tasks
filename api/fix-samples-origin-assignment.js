const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function fixSamplesOriginAssignment() {
  try {
    console.log('=== Fixing Samples Task Type Origin Assignment ===');
    
    // First, let's check the current state
    console.log('\n1. Checking current task type assignments for Samples...');
    const samplesTaskType = await prisma.taskType.findFirst({
      where: { name: 'Samples' },
      include: {
        task_type_department_assignments: {
          include: {
            departments: true
          }
        }
      }
    });
    
    if (!samplesTaskType) {
      console.log('❌ Samples task type not found!');
      return;
    }
    
    console.log('✅ Found Samples task type:', samplesTaskType.id);
    console.log('Current assignments:');
    samplesTaskType.task_type_department_assignments.forEach((assignment, index) => {
      console.log(`  Assignment ${index + 1}:`, {
        id: assignment.id,
        department: assignment.departments.name,
        is_origin: assignment.is_origin,
        is_destination: assignment.is_destination
      });
    });
    
    // Check if origin assignment already exists
    const existingOriginAssignment = samplesTaskType.task_type_department_assignments.find(a => a.is_origin);
    if (existingOriginAssignment) {
      console.log('✅ Origin assignment already exists for department:', existingOriginAssignment.departments.name);
      return;
    }
    
    // Find NICU department
    console.log('\n2. Looking for NICU department...');
    const nicuDepartment = await prisma.department.findFirst({
      where: { 
        name: {
          contains: 'NICU'
        }
      },
      include: {
        buildings: true
      }
    });
    
    if (!nicuDepartment) {
      console.log('❌ NICU department not found! Let me show all departments:');
      const allDepartments = await prisma.department.findMany({
        include: {
          buildings: true
        },
        orderBy: {
          name: 'asc'
        }
      });
      
      console.log('Available departments:');
      allDepartments.forEach((dept, index) => {
        console.log(`  ${index + 1}. ${dept.name} (Building: ${dept.buildings.name})`);
      });
      
      // Look for departments that might be NICU-related
      const possibleNICU = allDepartments.filter(dept => 
        dept.name.toLowerCase().includes('nicu') || 
        dept.name.toLowerCase().includes('intensive') ||
        dept.name.toLowerCase().includes('icu') ||
        dept.name.toLowerCase().includes('neo')
      );
      
      if (possibleNICU.length > 0) {
        console.log('\nPossible NICU-related departments:');
        possibleNICU.forEach((dept, index) => {
          console.log(`  ${index + 1}. ${dept.name} (${dept.id})`);
        });
        
        // Use the first possible NICU department
        const selectedDept = possibleNICU[0];
        console.log(`\n3. Using department: ${selectedDept.name} as origin for Samples`);
        
        // Create the origin assignment
        const newAssignment = await prisma.task_type_department_assignments.create({
          data: {
            task_type_id: samplesTaskType.id,
            department_id: selectedDept.id,
            is_origin: true,
            is_destination: false
          }
        });
        
        console.log('✅ Created new origin assignment:', newAssignment.id);
      } else {
        console.log('❌ No NICU-related departments found. Please manually specify the department.');
        return;
      }
    } else {
      console.log('✅ Found NICU department:', nicuDepartment.name, '(', nicuDepartment.id, ')');
      
      // Create the origin assignment
      console.log('\n3. Creating origin assignment...');
      const newAssignment = await prisma.task_type_department_assignments.create({
        data: {
          task_type_id: samplesTaskType.id,
          department_id: nicuDepartment.id,
          is_origin: true,
          is_destination: false
        }
      });
      
      console.log('✅ Created new origin assignment:', newAssignment.id);
    }
    
    // Verify the fix
    console.log('\n4. Verifying the fix...');
    const updatedAssignments = await prisma.task_type_department_assignments.findMany({
      where: { task_type_id: samplesTaskType.id },
      include: {
        departments: true
      }
    });
    
    console.log('Updated assignments for Samples task type:');
    updatedAssignments.forEach((assignment, index) => {
      console.log(`  Assignment ${index + 1}:`, {
        id: assignment.id,
        department: assignment.departments.name,
        is_origin: assignment.is_origin,
        is_destination: assignment.is_destination
      });
    });
    
    const hasOrigin = updatedAssignments.some(a => a.is_origin);
    const hasDestination = updatedAssignments.some(a => a.is_destination);
    
    if (hasOrigin && hasDestination) {
      console.log('\n✅ SUCCESS: Samples task type now has both origin and destination assignments!');
      console.log('The "From" field should now auto-populate when selecting Samples task type.');
    } else {
      console.log('\n❌ ISSUE: Missing assignments:');
      if (!hasOrigin) console.log('  - Missing origin assignment');
      if (!hasDestination) console.log('  - Missing destination assignment');
    }
    
  } catch (error) {
    console.error('❌ Error fixing Samples origin assignment:', error);
  } finally {
    await prisma.$disconnect();
  }
}

fixSamplesOriginAssignment();
