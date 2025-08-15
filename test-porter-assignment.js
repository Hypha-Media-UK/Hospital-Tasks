// Test script to verify porter assignment API endpoints work
import fetch from 'node-fetch';

const API_BASE = 'http://localhost:3000/api';

async function testPorterAssignmentAPI() {
  console.log('🧪 Testing Porter Assignment API Implementation...\n');
  
  try {
    // 1. Test getting area cover assignments
    console.log('1. Testing GET /api/area-cover/assignments');
    const assignmentsResponse = await fetch(`${API_BASE}/area-cover/assignments`);
    const assignments = await assignmentsResponse.json();
    console.log(`✅ Found ${assignments.length} area cover assignments`);
    
    if (assignments.length === 0) {
      console.log('❌ No area cover assignments found - cannot test porter assignments');
      return;
    }
    
    // Use the first assignment for testing
    const testAssignment = assignments[0];
    console.log(`📋 Using assignment: ${testAssignment.department.name} (${testAssignment.id})\n`);
    
    // 2. Test getting porter assignments for this area
    console.log('2. Testing GET /api/area-cover/assignments/:id/porter-assignments');
    const porterAssignmentsResponse = await fetch(`${API_BASE}/area-cover/assignments/${testAssignment.id}/porter-assignments`);
    const porterAssignments = await porterAssignmentsResponse.json();
    console.log(`✅ Found ${porterAssignments.length} existing porter assignments`);
    
    // 3. Test getting available porters
    console.log('\n3. Testing GET /api/staff?role=porter');
    const portersResponse = await fetch(`${API_BASE}/staff?role=porter`);
    const porters = await portersResponse.json();
    console.log(`✅ Found ${porters.length} porters available`);
    
    if (porters.length === 0) {
      console.log('❌ No porters found - cannot test porter assignment creation');
      return;
    }
    
    // Use the first porter for testing
    const testPorter = porters[0];
    console.log(`👤 Using porter: ${testPorter.first_name} ${testPorter.last_name} (${testPorter.id})`);
    
    // 4. Test creating a porter assignment
    console.log('\n4. Testing POST /api/area-cover/assignments/:id/porter-assignments');
    const createData = {
      porter_id: testPorter.id,
      start_time: '09:00',
      end_time: '17:00'
    };
    
    const createResponse = await fetch(`${API_BASE}/area-cover/assignments/${testAssignment.id}/porter-assignments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(createData)
    });
    
    if (createResponse.ok) {
      const newAssignment = await createResponse.json();
      console.log(`✅ Successfully created porter assignment (ID: ${newAssignment.id})`);
      
      // 5. Test updating the porter assignment
      console.log('\n5. Testing PUT /api/area-cover/porter-assignments/:id');
      const updateData = {
        start_time: '08:00',
        end_time: '16:00'
      };
      
      const updateResponse = await fetch(`${API_BASE}/area-cover/porter-assignments/${newAssignment.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(updateData)
      });
      
      if (updateResponse.ok) {
        const updatedAssignment = await updateResponse.json();
        console.log(`✅ Successfully updated porter assignment`);
        console.log(`   Time changed from ${createData.start_time}-${createData.end_time} to ${updateData.start_time}-${updateData.end_time}`);
        
        // 6. Test deleting the porter assignment
        console.log('\n6. Testing DELETE /api/area-cover/porter-assignments/:id');
        const deleteResponse = await fetch(`${API_BASE}/area-cover/porter-assignments/${newAssignment.id}`, {
          method: 'DELETE'
        });
        
        if (deleteResponse.ok) {
          console.log(`✅ Successfully deleted porter assignment`);
        } else {
          console.log(`❌ Failed to delete porter assignment: ${deleteResponse.status}`);
        }
      } else {
        console.log(`❌ Failed to update porter assignment: ${updateResponse.status}`);
      }
    } else {
      const errorText = await createResponse.text();
      console.log(`❌ Failed to create porter assignment: ${createResponse.status}`);
      console.log(`   Error: ${errorText}`);
    }
    
    console.log('\n🎉 Porter Assignment API Test Complete!');
    
  } catch (error) {
    console.error('❌ Test failed with error:', error.message);
  }
}

// Run the test
testPorterAssignmentAPI();
