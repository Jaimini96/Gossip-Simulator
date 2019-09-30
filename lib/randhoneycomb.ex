defmodule Randhoneycomb do
  use GenServer

  # DECISION : GOSSIP vs PUSH_SUM
  def init([x,numberOfNodes, is_push_sum]) do
    mates = droid_mates(x,numberOfNodes)
    # IO.puts Enum.at(mates,1)
    case is_push_sum do
      0 -> {:ok, [Active,0,0, numberOfNodes, x | mates] } #[ status, rec_count, sent_count, n, self_number_id | neighbors ]
      1 -> {:ok, [Active,0, 0, 0, 0, x, 1, numberOfNodes, x| mates] } #[status, rec_count,streak,prev_s_w,to_terminate, s, w, n, self_number_id | neighbors ]
    end
  end

    # GOSSIP - RECIEVE Main
  def handle_cast({:message_gossip, _received}, [status,count,sent,numberOfNodes,x| mates ] =state ) do
    length = round(Float.ceil(:math.sqrt(numberOfNodes)))
    i = rem(x-1,length) + 1
    j = round(Float.floor(((x-1)/length))) + 1
    case count < 200 do
      true ->  GenServer.cast(Master,{:received, [{i,j}]})
               gossip(x,mates,self(),numberOfNodes,i,j)
      false -> GenServer.cast(Master,{:hibernated, [{i,j}]})
    end
    {:noreply,[status,count+1 ,sent,numberOfNodes, x  | mates]}
  end

  # GOSSIP  - SEND Main
  def gossip(x,mates,pid, n,i,j) do
    the_one = the_chosen_one(mates)
    GenServer.cast(the_one, {:message_gossip, :_sending})
    # case GenServer.call(the_one,:is_active) do
      # Active -> GenServer.cast(the_one, {:message_gossip, :_sending})
      # ina_xy -> GenServer.cast(Master,{:droid_inactive, ina_xy})
      #           new_mate = GenServer.call(Master,:handle_node_failure)
      #           GenServer.cast(self(),{:remove_mate,the_one})
      #           GenServer.cast(self(),{:add_new_mate,new_mate})
      #           GenServer.cast(new_mate,{:add_new_mate,droid_name(x)})
      #           GenServer.cast(self(),{:retry_gossip,{pid,i,j}})
    # end
  end

  def droid_mates(self,n) do
    elementsPerRow = round(:math.sqrt(n))
    neighbors =[getFirstNeighbor(self,elementsPerRow),getSecondNeighbor(self,elementsPerRow,n), getThirdNeighbor(self,elementsPerRow,n)]
    filteredNeighbors = Enum.filter(neighbors, fn(x) -> x != nil end)
    # IO.puts filteredNeighbors
    neighborIds = Enum.map(filteredNeighbors, fn(x) -> droid_name(x) end)
    # IO.inspect Enum.at(neighbors,0)
    neighborIds

  end

  def getFirstNeighbor(x,elemPerRow) do
    if (x-elemPerRow) >= 1 do
      x-elemPerRow
    end
  end
  def getSecondNeighbor(x,elemPerRow, n) do
    if (x+elemPerRow) <= n do
      x+elemPerRow
    end
  end
  def getThirdNeighbor(x,elemPerRow, n)  do
    isLastElementInRow = rem(x,elemPerRow) == 0

    rowNumber = case isLastElementInRow do
      true -> round(div(x,round(elemPerRow)))-1
      false -> round(div(x,round(elemPerRow)))
    end

    remainder = rem(rowNumber,2)
    isXOdd = rem(x,2)
    # IO.puts("x: #{x}, elePerRow: #{elemPerRow}, n: #{n}, rownumber: #{rowNumber}, islastEl: #{isLastElementInRow} remainder: #{remainder}, isXOdd : #{isXOdd}")
    # case remainder do
    #   true -> case isXOdd && x > 1 do
    #     true -> round(x-1)
    #   end
    # end
    neighbor  = cond do
      remainder == 0 && isXOdd == 0 && x > 1 && rem(x,elemPerRow) > 1 ->
        # IO.puts "Came"
        round(x-1)
      remainder == 0 && isXOdd == 1 && x< n ->
        round(x+1)
      remainder == 1 && isXOdd == 1 && x > 1 ->
        round(x-1)
      remainder == 1 && isXOdd == 0 && x< n ->
        round(x+1)
      x == 0 || x==n || rem(x, elemPerRow) <2->
        nil
      end

    # IO.puts neighbor
    neighbor

  end

  def create_network(numberOfNodes, is_push_sum \\ 0) do
    droids =
      for x <- 1..numberOfNodes do
        name = droid_name(x)
        GenServer.start_link(Randhoneycomb, [x,numberOfNodes, is_push_sum], name: name)
        name
      end
    GenServer.cast(Master,{:droids_update,droids})
  end

  def droid_name(x) do
    a = x|> Integer.to_string |> String.pad_leading(7,"0")
    "Elixir.D"<>a
    |>String.to_atom
  end

  def the_chosen_one(neighbors) do
    Enum.random(neighbors)
  end

end
