import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function addSampleAreaPorterAssignments() {
  try {
    console.log('🔍 Checking existing data...');
    
    // Get all area cover assignments
    const areaAssignments = await prisma.default_area_cover_assignments.findMany({
      include: {
        departments: true
      }
    });
    
    console.log(`Found ${areaAssignments.length} area cover assignments`);
    
    // Get all porter staff
    const porters = await prisma.staff.findMany({
      where: { role: 'porter' }
    });
    
    console.log(`Found ${porters.length} porters`);
    
    if (areaAssignments.length === 0 || porters.length === 0) {
      console.log('❌ No area assignments or porters found. Cannot add sample data.');
      return;
    }
    
    // Check if there are already porter assignments
    const existingAssignments = await prisma.default_area_cover_porter_assignments.findMany();
    console.log(`Found ${existingAssignments.length} existing porter assignments`);
    
    if (existingAssignments.length > 0) {
      console.log('✅ Porter assignments already exist. Skipping sample data creation.');
      return;
    }
    
    console.log('📝 Adding sample porter assignments...');
    
    // Add sample porter assignments for each area
    let assignmentCount = 0;
    
    for (const area of areaAssignments) {
      // Assign 1-2 porters to each area
      const numPorters = Math.min(2, porters.length);
      const selectedPorters = porters.slice(0, numPorters);
      
      for (let i = 0; i < selectedPorters.length; i++) {
        const porter = selectedPorters[i];
        
        // Create different time slots for different porters
        const startHour = 9 + (i * 4); // 09:00, 13:00, etc.
        const endHour = startHour + 8; // 8-hour shifts
        
        const startTime = new Date(`1970-01-01T${String(startHour).padStart(2, '0')}:00:00`);
        const endTime = new Date(`1970-01-01T${String(Math.min(endHour, 21)).padStart(2, '0')}:00:00`);
        
        await prisma.default_area_cover_porter_assignments.create({
          data: {
            default_area_cover_assignment_id: area.id,
            porter_id: porter.id,
            start_time: startTime,
            end_time: endTime
          }
        });
        
        assignmentCount++;
        console.log(`✅ Added ${porter.first_name} ${porter.last_name} to ${area.departments.name} (${String(startHour).padStart(2, '0')}:00 - ${String(Math.min(endHour, 21)).padStart(2, '0')}:00)`);
      }
    }
    
    console.log(`🎉 Successfully added ${assignmentCount} sample porter assignments!`);
    
  } catch (error) {
    console.error('❌ Error adding sample data:', error);
  } finally {
    await prisma.$disconnect();
  }
}

addSampleAreaPorterAssignments();
