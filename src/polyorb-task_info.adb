------------------------------------------------------------------------------
--                                                                          --
--                           POLYORB COMPONENTS                             --
--                                                                          --
--                    P O L Y O R B . T A S K _ I N F O                     --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2001-2004 Free Software Foundation, Inc.           --
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

--  Information about running ORB tasks.

--  This package is used to store and retrieve information
--  concerning the status of tasks that execute ORB functions.

--  $Id$

package body PolyORB.Task_Info is

   -----------
   -- Image --
   -----------

   function Image (TI : Task_Info) return String is
   begin
      return Tasking.Threads.Image (TI.Id);
   end Image;

   --------------
   -- May_Poll --
   --------------

   function May_Poll (TI : Task_Info) return Boolean is
   begin
      return TI.May_Poll;
   end May_Poll;

   --------------
   -- Selector --
   --------------

   function Selector
     (TI : Task_Info)
     return Asynch_Ev.Asynch_Ev_Monitor_Access
   is
   begin
      pragma Assert (TI.State = Blocked);

      return TI.Selector;
   end Selector;

   -----------------------
   -- Set_State_Blocked --
   -----------------------

   procedure Set_State_Blocked
     (TI       : in out Task_Info;
      Selector :        Asynch_Ev.Asynch_Ev_Monitor_Access)
   is
   begin
      TI.State    := Blocked;
      TI.Selector := Selector;
   end Set_State_Blocked;

   --------------------
   -- Set_State_Idle --
   --------------------

   procedure Set_State_Idle
     (TI        : in out Task_Info;
      Condition :        PTCV.Condition_Access;
      Mutex     :        PTM.Mutex_Access)
   is
   begin
      TI.State     := Idle;
      TI.Condition := Condition;
      TI.Mutex     := Mutex;
   end Set_State_Idle;

   -----------------------
   -- Set_State_Running --
   -----------------------

   procedure Set_State_Running (TI : in out Task_Info) is
   begin
      TI.State     := Running;
      TI.Selector  := null;
      TI.Condition := null;
      TI.Mutex     := null;
   end Set_State_Running;

   -----------
   -- State --
   -----------

   function State (TI : Task_Info) return Task_State is
   begin
      return TI.State;
   end State;

   ---------------
   -- Condition --
   ---------------

   function Condition (TI : Task_Info) return PTCV.Condition_Access is
   begin
      return TI.Condition;
   end Condition;

   --------------------
   -- Exit_Condition --
   --------------------

   function Exit_Condition (TI : Task_Info) return Boolean is
      use type PolyORB.Types.Boolean_Ptr;

   begin
      return TI.Exit_Condition /= null and then TI.Exit_Condition.all;
   end Exit_Condition;

   -----------
   -- Mutex --
   -----------

   function Mutex (TI : Task_Info) return PTM.Mutex_Access is
   begin
      return TI.Mutex;
   end Mutex;

   ------------------------
   -- Set_Exit_Condition --
   ------------------------

   procedure Set_Exit_Condition
     (TI             : in out Task_Info;
      Exit_Condition :        PolyORB.Types.Boolean_Ptr)
   is
      use type PolyORB.Types.Boolean_Ptr;

   begin
      pragma Assert ((TI.Kind = Transient and then Exit_Condition /= null)
                     or else (TI.Kind = Permanent
                              and then Exit_Condition = null));

      TI.Exit_Condition := Exit_Condition;
   end Set_Exit_Condition;

   ------------
   -- Set_Id --
   ------------

   procedure Set_Id (TI : in out Task_Info) is
   begin
      TI.Id := Tasking.Threads.Current_Task;
   end Set_Id;

   -----------------
   -- Set_Polling --
   -----------------

   procedure Set_Polling (TI : in out Task_Info; May_Poll : Boolean) is
   begin
      TI.May_Poll := May_Poll;
   end Set_Polling;

   ---------------------------
   -- Set_State_Unscheduled --
   ---------------------------

   procedure Set_State_Unscheduled (TI : in out Task_Info) is
   begin
      pragma Assert (TI.State /= Unscheduled);

      TI.State     := Unscheduled;
      TI.Selector  := null;
      TI.Condition := null;
      TI.Mutex     := null;
   end Set_State_Unscheduled;

   ---------------------------
   -- Request_Abort_Polling --
   ---------------------------

   procedure Request_Abort_Polling (TI : in out Task_Info) is
   begin
      pragma Assert (TI.State = Blocked);

      TI.Abort_Polling := True;
   end Request_Abort_Polling;

   -------------------
   -- Abort_Polling --
   -------------------

   function Abort_Polling (TI : Task_Info) return Boolean is
   begin
      pragma Assert (TI.State = Blocked);

      return TI.Abort_Polling;
   end Abort_Polling;

end PolyORB.Task_Info;