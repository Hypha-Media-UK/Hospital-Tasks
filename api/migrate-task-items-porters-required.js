const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function migrateTaskItemsPortersRequired() {
  console.log('Starting migration: Setting default porters_required = 1 for existing task items...');
  
  try {
    // Update all existing task items that don't have porters_required set
    const result = await prisma.taskItem.updateMany({
      where: {
        porters_required: null
      },
      data: {
        porters_required: 1
      }
    });
    
    console.log(`✅ Successfully updated ${result.count} task items with default porters_required = 1`);
    
    // Verify the migration
    const totalTaskItems = await prisma.taskItem.count();
    const taskItemsWithPortersRequired = await prisma.taskItem.count({
      where: {
        porters_required: {
          not: null
        }
      }
    });
    
    console.log(`📊 Migration verification:`);
    console.log(`   Total task items: ${totalTaskItems}`);
    console.log(`   Task items with porters_required set: ${taskItemsWithPortersRequired}`);
    
    if (totalTaskItems === taskItemsWithPortersRequired) {
      console.log('✅ Migration completed successfully - all task items now have porters_required set');
    } else {
      console.log('⚠️  Warning: Some task items may still be missing porters_required values');
    }
    
  } catch (error) {
    console.error('❌ Error during migration:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run the migration if this script is executed directly
if (require.main === module) {
  migrateTaskItemsPortersRequired()
    .then(() => {
      console.log('Migration completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Migration failed:', error);
      process.exit(1);
    });
}

module.exports = { migrateTaskItemsPortersRequired };
