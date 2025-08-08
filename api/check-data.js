const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function checkData() {
  try {
    console.log('=== Checking Shift Defaults ===');
    const shiftDefaults = await prisma.shift_defaults.findMany();
    console.log('Shift defaults count:', shiftDefaults.length);
    console.log('Shift defaults:', JSON.stringify(shiftDefaults, null, 2));

    console.log('\n=== Checking Default Area Cover Assignments ===');
    const areaCoverDefaults = await prisma.default_area_cover_assignments.findMany({
      include: {
        departments: true
      }
    });
    console.log('Area cover defaults count:', areaCoverDefaults.length);
    console.log('Area cover defaults:', JSON.stringify(areaCoverDefaults, null, 2));

    console.log('\n=== Checking Default Service Cover Assignments ===');
    const serviceCoverDefaults = await prisma.default_service_cover_assignments.findMany({
      include: {
        support_services: true
      }
    });
    console.log('Service cover defaults count:', serviceCoverDefaults.length);
    console.log('Service cover defaults:', JSON.stringify(serviceCoverDefaults, null, 2));

    console.log('\n=== Checking Recent Shift ===');
    const recentShift = await prisma.shifts.findFirst({
      orderBy: { created_at: 'desc' },
      include: {
        staff: true
      }
    });
    console.log('Recent shift:', JSON.stringify(recentShift, null, 2));

  } catch (error) {
    console.error('Error checking data:', error);
  } finally {
    await prisma.$disconnect();
  }
}

checkData();
