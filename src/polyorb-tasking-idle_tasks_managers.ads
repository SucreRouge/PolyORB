------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--  P O L Y O R B . T A S K I N G . I D L E _ T A S K S _ M A N A G E R S   --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--            Copyright (C) 2004 Free Software Foundation, Inc.             --
--                                                                          --
-- PolyORB is free software; you  can  redistribute  it and/or modify it    --
-- under terms of the  GNU General Public License as published by the  Free --
-- Software Foundation;  either version 2,  or (at your option)  any  later --
-- version. PolyORB is distributed  in the hope that it will be  useful,    --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License  for more details.  You should have received  a copy of the GNU  --
-- General Public License distributed with PolyORB; see file COPYING. If    --
-- not, write to the Free Software Foundation, 59 Temple Place - Suite 330, --
-- Boston, MA 02111-1307, USA.                                              --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable  to  be --
-- covered  by the  GNU  General  Public  License.  This exception does not --
-- however invalidate  any other reasons why  the executable file  might be --
-- covered by the  GNU Public License.                                      --
--                                                                          --
--                PolyORB is maintained by ACT Europe.                      --
--                    (email: sales@act-europe.fr)                          --
--                                                                          --
------------------------------------------------------------------------------

--  $Id$

with PolyORB.Task_Info;
with PolyORB.Tasking.Condition_Variables;
with PolyORB.Utils.Chained_Lists;

package PolyORB.Tasking.Idle_Tasks_Managers is

   package PTI renames PolyORB.Task_Info;
   package PTCV renames PolyORB.Tasking.Condition_Variables;

   type Idle_Tasks_Manager is limited private;

   type Idle_Tasks_Manager_Access is access all Idle_Tasks_Manager;

   procedure Awake_One_Idle_Task (ITM : access Idle_Tasks_Manager);
   --  Awake one idle task, if any, else do nothing

   procedure Remove_Idle_Task
     (ITM : access Idle_Tasks_Manager;
      TI  :        PTI.Task_Info_Access);
   --  Remove TI from the pool of tasks managed by ITM

   function Insert_Idle_Task
     (ITM  : access Idle_Tasks_Manager;
      TI  :        PTI.Task_Info_Access)
     return PTCV.Condition_Access;
   --  Add TI to the pool of tasks managed by ITM. The returned CV
   --  will be used by a task to put itself in an idle (waiting) state.

private

   pragma Inline (Awake_One_Idle_Task);
   pragma Inline (Remove_Idle_Task);
   pragma Inline (Insert_Idle_Task);

   package Task_Lists renames PTI.Task_Lists;

   package CV_Lists is
     new PolyORB.Utils.Chained_Lists (PTCV.Condition_Access, PTCV."=");

   type Idle_Tasks_Manager is limited record
      Idle_Task_List : Task_Lists.List;
      --  List of idle tasks

      Free_CV : CV_Lists.List;
      --  Free_CV is the list of pre-allocated CV. When scheduling a task
      --  to idle state, the ORB controller first looks for an availble
      --  CV in this list; or else allocates one new CV. When a task
      --  leaves idle state, the ORB controller puts its CV in Free_CV.
   end record;

end PolyORB.Tasking.Idle_Tasks_Managers;
