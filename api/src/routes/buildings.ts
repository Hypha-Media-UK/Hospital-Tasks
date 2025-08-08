import { Router, Request, Response } from 'express';
import { prisma } from '../server';

const router = Router();

// GET /api/buildings - Get all buildings
router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const buildings = await prisma.building.findMany({
      include: {
        departments: {
          orderBy: {
            sort_order: 'asc'
          }
        }
      },
      orderBy: {
        sort_order: 'asc'
      }
    });
    
    res.json(buildings);
  } catch (error) {
    console.error('Error fetching buildings:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch buildings'
    });
  }
});

// GET /api/buildings/:id - Get specific building
router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const building = await prisma.building.findUnique({
      where: { id }
    });

    if (!building) {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Building not found'
      });
      return;
    }

    res.json(building);
  } catch (error) {
    console.error('Error fetching building:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to fetch building'
    });
  }
});

// POST /api/buildings - Create new building
router.post('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const { name, address } = req.body;

    if (!name) {
      res.status(400).json({
        error: 'Bad Request',
        message: 'name is required'
      });
      return;
    }

    const building = await prisma.building.create({
      data: {
        name,
        address: address || null
      }
    });

    res.status(201).json(building);
  } catch (error) {
    console.error('Error creating building:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to create building'
    });
  }
});

// PUT /api/buildings/:id - Update building
router.put('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };
    delete updateData.id;

    const building = await prisma.building.update({
      where: { id },
      data: updateData
    });

    res.json(building);
  } catch (error: any) {
    console.error('Error updating building:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Building not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to update building'
    });
  }
});

// DELETE /api/buildings/:id - Delete building
router.delete('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    await prisma.building.delete({
      where: { id }
    });

    res.status(204).send();
  } catch (error: any) {
    console.error('Error deleting building:', error);
    
    if (error.code === 'P2025') {
      res.status(404).json({ 
        error: 'Not Found',
        message: 'Building not found'
      });
      return;
    }
    
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: 'Failed to delete building'
    });
  }
});

export default router;
